public with sharing class PassthroughtModeService {

    public static void sendInboundEmail(Inbound_Email__c iemail) {

        Connected_Org__c connectedPharosOrg = ConnectedOrgService.getPassthroughConnectedOrg();
        if (connectedPharosOrg == null) {
            throw new PassthroughtModeServiceException(ConfigUtil.CONNECTED_ORG_NOT_FOUND_PASSTHROUGHMODE);
        }

        String body = JSON.serialize(new Map<String, Object>{
            'inboundEmail' => iemail,
            'organizationId' => UserInfo.getOrganizationId()
        });

        String b = HttpUtils.post(
            connectedPharosOrg.Instance_Url__c + ConfigUtil.PHAROS_REST_SERVICE_ENDPOINT + '?' + ConfigUtil.PARAMS_TYPE + '=' + ConfigUtil.TYPE_PASSTHROUGH_MODE,
            body,
            ConfigUtil.getSFRestAPIHeaders(ConnectedOrgService.getConnectedOrgAccessToken(connectedPharosOrg)),
            200
        );

    }

    public static void sendLog(Log__c log) {
        sendLogs(new List<Log__c>{log});
    }

    public static void sendLogs(List<Log__c> logs) {
        Connected_Org__c connectedPharosOrg = ConnectedOrgService.getPassthroughConnectedOrg();
        if (connectedPharosOrg == null) {
            throw new PassthroughtModeServiceException(ConfigUtil.CONNECTED_ORG_NOT_FOUND_PASSTHROUGHMODE);
        }

        String body = JSON.serialize(new Map<String, Object>{
            'logs' => logs,
            'organizationId' => UserInfo.getOrganizationId()
        });

        String b = HttpUtils.post(
            connectedPharosOrg.Instance_Url__c + ConfigUtil.PHAROS_REST_SERVICE_ENDPOINT + '?' + ConfigUtil.PARAMS_TYPE + '=' + ConfigUtil.TYPE_PASSTHROUGH_MODE,
            body,
            ConfigUtil.getSFRestAPIHeaders(ConnectedOrgService.getConnectedOrgAccessToken(connectedPharosOrg)),
            200
        );
    }

    public static void sendContentVersion(BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper) {

        Connected_Org__c connectedPharosOrg = ConnectedOrgService.getPassthroughConnectedOrg();
        if (connectedPharosOrg == null) {
            throw new PassthroughtModeServiceException(ConfigUtil.CONNECTED_ORG_NOT_FOUND_PASSTHROUGHMODE);
        }

        String body = JSON.serialize(new Map<String, Object>{
                'contentVersionWrapper' => contentVersionWrapper,
                'organizationId' => UserInfo.getOrganizationId()
        });

        String b = HttpUtils.post(
                connectedPharosOrg.Instance_Url__c + ConfigUtil.PHAROS_REST_SERVICE_ENDPOINT + '?' + ConfigUtil.PARAMS_TYPE + '=' + ConfigUtil.TYPE_PASSTHROUGH_MODE,
                body,
                ConfigUtil.getSFRestAPIHeaders(ConnectedOrgService.getConnectedOrgAccessToken(connectedPharosOrg)),
                200
        );
    }

    public static void parseIncomingData(IncomingLogData data) {
        if (data.logs != null) {
            PermissionsUtil.putSObjectFields(data.logs, Schema.SObjectType.Log__c.fields.Originated_From__c, ConfigUtil.ORIGINATED_FROM_PASSTHROUGH, true);
            LogEventTriggerHandler.addOrgInfoForManualLog(data.logs, Datetime.now());
            PermissionsUtil.performUpsertDML(data.logs, Schema.SObjectType.Log__c);
        }
        else if (data.inboundEmail != null) {
            PermissionsUtil.putSObjectField(data.inboundEmail, Schema.SObjectType.Inbound_Email__c.fields.Id, null);
            PermissionsUtil.putSObjectField(data.inboundEmail, Schema.SObjectType.Inbound_Email__c.fields.Pharos_Org_ID__c, data.organizationId);
            ErrorEmailHandler.processEmail(new List<Inbound_Email__c>{data.inboundEmail}, data.organizationId);
        }
        else if (data.contentVersionWrapper != null) {
            ContentVersion contentVersion = data.contentVersionWrapper.contentVersion;
            contentVersion.VersionData = Blob.valueOf(data.contentVersionWrapper.contentVersionData);
            insert contentVersion;
        }
    }

    public class IncomingLogData {
        public List<Log__c> logs;
        public Inbound_Email__c inboundEmail;
        public BulkAPIJobBatchService.ContentVersionWrapper contentVersionWrapper;
        public String organizationId;

        public IncomingLogData() {
            this.logs = new List<Log__c>();
        }

    }

    public class PassthroughtModeServiceException extends Exception {}

}