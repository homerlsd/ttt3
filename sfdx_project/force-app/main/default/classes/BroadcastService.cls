public with sharing class BroadcastService {

    private static final Integer MAX_SIZE_OF_JSON = 2500000;

    public static void sendLog(Log__c log) {
        sendLogs(new List<Log__c>{log});
    }

    public static void sendLogs(List<Log__c> logs) {
        List<Connected_Org__c> corgs = ConnectedOrgService.getBroadcastConnectedOrgs(ConnectedOrgService.BROADCAST_SEND_TO);
        if (!corgs.isEmpty()) {
            BroadcastChainQueueableJobs(logs, null, corgs);
        }
    }

    public static void sendContentVersion(Log__c log, BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper) {
        List<Connected_Org__c> corgs = ConnectedOrgService.getBroadcastConnectedOrgs(ConnectedOrgService.BROADCAST_SEND_TO);
        if (!corgs.isEmpty()) {
            BroadcastChainQueueableJobs(new List<Log__c>{log}, contentVersionWrapper, corgs);
        }
    }

    private static void BroadcastChainQueueableJobs(List<Log__c> logs, BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper, List<Connected_Org__c> corgs) {
        if (!Test.isRunningTest()) {
            QueueableJobChain chain = new QueueableJobChain();
            Map<String, MonitoringUtil.MonitoringRule> mapRulesByRelatedId = getMapRulesByRelatedId();
            for (Connected_Org__c corg : corgs) {
                Integer size = 0;
                List<Log__c> logsToSend = new List<Log__c>();
                for (Log__c log : mapRulesByRelatedId.containsKey(corg.Id) ? mapRulesByRelatedId.get(corg.Id).applyRuleFilters(logs) : logs) {
                    size += JSON.serialize(log).length();
                    logsToSend.add(log);
                    if (size >= MAX_SIZE_OF_JSON) {
                        chain.chainLast(contentVersionWrapper != null ? new BroadcastChainedQueueable(chain,  contentVersionWrapper, corg) : new BroadcastChainedQueueable(chain,  logsToSend, corg));
                        size = 0;
                        logsToSend = new List<Log__c>();
                    }
                }
                if (!logsToSend.isEmpty()) {
                    chain.chainLast(contentVersionWrapper != null ? new BroadcastChainedQueueable(chain,  contentVersionWrapper, corg) : new BroadcastChainedQueueable(chain,  logsToSend, corg));
                }
            }
            chain.runNext();
        }
    }

    public static Map<String, MonitoringUtil.MonitoringRule> getMapRulesByRelatedId() {
        Map<String, MonitoringUtil.MonitoringRule> mapRulesByRelatedId = new Map<String, MonitoringUtil.MonitoringRule>();
        for (MonitoringUtil.MonitoringRule monitoringRule : MonitoringUtil.getBroadcastRules(null)) {
            mapRulesByRelatedId.put(monitoringRule.relatedId, monitoringRule);
        }
        return mapRulesByRelatedId;
    }

    public class BroadcastChainedQueueable extends ChainedQueuable implements Database.AllowsCallouts {
        private List<Log__c> logs;
        private Map<String, String> mapRecordTypesById;
        private BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper;
        private Connected_Org__c corg;
        public BroadcastChainedQueueable(QueueableJobChain chain, List<Log__c> logs, Connected_Org__c corg) {
            super(chain);
            this.logs = logs;
            mapRecordTypesById = new Map<String, String>();
            for (String id : Schema.SObjectType.Log__c.getRecordTypeInfosById().keySet()) {
                mapRecordTypesById.put(id, Schema.SObjectType.Log__c.getRecordTypeInfosById().get(id).getName());
            }
            this.corg = corg;
        }
        public BroadcastChainedQueueable(QueueableJobChain chain, BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper, Connected_Org__c corg) {
            super(chain);
            this.contentVersionWrapper = contentVersionWrapper;
            this.corg = corg;
        }
        public override void execute(QueueableContext context) {
            String body = JSON.serialize(new Map<String, Object>{
                    'logs' => logs != null ? getFormattedLogs(logs.deepClone()) : null,
                    'mapRecordTypesById' => mapRecordTypesById,
                    'contentVersionWrapper' => contentVersionWrapper,
                    'organizationId' => UserInfo.getOrganizationId()
            });
            try {
                String b = HttpUtils.post(
                        corg.Instance_Url__c + ConfigUtil.PHAROS_REST_SERVICE_ENDPOINT + '?' + ConfigUtil.PARAMS_TYPE + '=' + ConfigUtil.TYPE_BROADCAST,
                        body,
                        ConfigUtil.getSFRestAPIHeaders(ConnectedOrgService.getConnectedOrgAccessToken(corg)),
                        200
                );
            }
            catch (Exception e) {
                Logger.getInstance().internalError(e, corg.Name, true, BroadcastService.class.getName(), 'execute');
            }
            super.execute(context); // runs the next queueable in the chain.
        }
        private List<Log__c> getFormattedLogs(List<Log__c> logs) {
            for (Log__c log : logs) {
                if (String.isBlank(log.Organization_Url__c)) {
                    PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Organization_Url__c, System.Url.getOrgDomainUrl().toExternalForm());
                }
                if (String.isBlank(log.User_Id__c) || String.isBlank(log.User_Name__c)) {
                    PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.User_Id__c, UserInfo.getUserId());
                    PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.User_Name__c, UserInfo.getName());
                }
                log.Jira_Integration_Status__c = null;
                log.Bug_Tracker__c = null;
                log.Notification_Integration_Status__c = null;
                log.PagerDuty_Integration_Status__c = null;
                log.Slack_Integration_Status__c = null;
                log.Email_Integration_Status__c = null;
            }
            return logs;
        }
    }

    public static void parseIncomingData(IncomingData data) {
        if (String.isNotBlank(data.organizationId)) {
            Connected_Org__c corg;
            for (Connected_Org__c connectedOrg : ConnectedOrgService.getBroadcastConnectedOrgs(ConnectedOrgService.BROADCAST_RECEIVE_FROM)) {
                if (connectedOrg.Name == data.organizationId.left(15)) {
                    corg = connectedOrg;
                    break;
                }
            }
            if (corg != null) {
                if (data.logs != null && !data.logs.isEmpty()) {
                    List<Log__c> logsForInsert = new List<Log__c>();
                    Map<String, Schema.RecordTypeInfo> mapRecordTypesByName = Schema.SObjectType.Log__c.getRecordTypeInfosByName();
                    for (Log__c log : data.logs) {
                        if (String.isNotBlank(String.valueOf(log.RecordTypeId))) {
                            log.RecordTypeId = mapRecordTypesByName.get(data.mapRecordTypesById.get(log.RecordTypeId)).getRecordTypeId();
                        }
                        Map<String, Object> mapLog = new Map<String, Object>(log.getPopulatedFieldsAsMap());
                        for (Schema.SObjectField sObjectField : Schema.SObjectType.Log__c.getSObjectType().getDescribe().fields.getMap().values()) {
                            if (String.valueOf(sObjectField.getDescribe().getType()) == 'REFERENCE' && sObjectField.getDescribe().getName() != 'RecordTypeId') {
                                mapLog.remove(sObjectField.getDescribe().getName());
                            }
                        }
                        logsForInsert.add((Log__c)JSON.deserialize(JSON.serialize(mapLog), Log__c.class));
                    }
                    PermissionsUtil.putSObjectFields(logsForInsert, Schema.SObjectType.Log__c.fields.Organization_Name__c, corg.Title__c, true);
                    PermissionsUtil.putSObjectFields(logsForInsert, Schema.SObjectType.Log__c.fields.Originated_From__c, ConfigUtil.ORIGINATED_FROM_BROADCAST, true);
                    PermissionsUtil.performInsertDML(logsForInsert, Schema.SObjectType.Log__c);
                } else if (data.contentVersionWrapper != null) {
                    ContentVersion contentVersion = data.contentVersionWrapper.contentVersion;
                    contentVersion.VersionData = Blob.valueOf(data.contentVersionWrapper.contentVersionData);
                    insert contentVersion;
                }
            }
        }
    }

    public class IncomingData {
        public List<Log__c> logs;
        public Map<String, String> mapRecordTypesById;
        public BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper;
        public String organizationId;
    }

    public class BroadcastServiceException extends Exception {}

}