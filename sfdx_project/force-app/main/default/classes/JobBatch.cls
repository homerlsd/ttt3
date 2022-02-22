public with sharing class JobBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, Database.RaisesPlatformEvents {

    private Integer LIMIT_DML_STATEMENTS = 200;
    private List<Log__c> logs;
    private Connected_Org__c corg;
    Map<String, Log__c> mapInternalLogsByHash = new Map<String, Log__c>();
    Map<String, Integer> mapInternalLogsCountByHash = new Map<String, Integer>();

    public JobBatch() {
        logs = new List<Log__c>();
        corg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId());
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        if (corg == null) {
            System.abortJob(BC.getJobId());
        }
        return Database.getQueryLocator([
                SELECT Id, JobType, ExtendedStatus, ApexClassId, ApexClass.Name, Status, CompletedDate
                FROM AsyncApexJob
                WHERE Status IN ('Completed', 'Failed')
                AND ParentJobId = NULL
                AND NumberOfErrors > 0
                AND CompletedDate >= LAST_WEEK
                ORDER BY CompletedDate
        ]);
    }

    public void execute(Database.BatchableContext BC, List<AsyncApexJob> scope) {
        Set<String> setAsyncApexJobIds = new Set<String>();
        Set<String> setApexClassIdIds = new Set<String>();
        for (AsyncApexJob asyncApexJob : scope) {
            String asyncApexJobId = asyncApexJob.Id;
            setAsyncApexJobIds.add(asyncApexJobId);
            setAsyncApexJobIds.add(asyncApexJobId.left(15));
            setApexClassIdIds.add(asyncApexJob.ApexClassId);
        }
        List<Log__c> logs = getLogs(setAsyncApexJobIds);
        Map<Id, ApexClass> mapInternalApexClasses = getInternalApexClasses(setApexClassIdIds);
        for (AsyncApexJob asyncApexJob : scope) {
            Boolean exist = false;
            Boolean isInternal = String.isNotBlank(asyncApexJob.ApexClassId) && mapInternalApexClasses.containsKey(asyncApexJob.ApexClassId);
            String hash = getHash(asyncApexJob) + String.valueOfGmt(asyncApexJob.CompletedDate.dateGmt());
            for (Log__c log : logs) {
                if (asyncApexJob.Id == log.Async_Job_Id__c) {
                    exist = true;
                    if (isInternal) {
                        if (!mapInternalLogsByHash.containsKey(hash)) {
                            mapInternalLogsByHash.put(hash, log);
                        }
                        mapInternalLogsCountByHash.put(hash, mapInternalLogsCountByHash.get(hash) == null ? 1 : mapInternalLogsCountByHash.get(hash) + 1);
                    }
                    break;
                }
            }
            if (!exist) {
                if (isInternal) {
                    if (!mapInternalLogsByHash.containsKey(hash)) {
                        mapInternalLogsByHash.put(hash, createLog(asyncApexJob, isInternal));
                    }
                    mapInternalLogsCountByHash.put(hash, mapInternalLogsCountByHash.get(hash) == null ? 1 : mapInternalLogsCountByHash.get(hash) + 1);
                } else if (logs.size() <= LIMIT_DML_STATEMENTS) {
                    logs.add(createLog(asyncApexJob, isInternal));
                }
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        for (String hash : mapInternalLogsByHash.keySet()) {
            Log__c log = mapInternalLogsByHash.get(hash);
            log.Details__c = log.Details__c.replaceFirst('\nFailures count: [0-9]+$', '');
            log.Details__c += '\nFailures count: ' + mapInternalLogsCountByHash.get(hash);
        }
        logs.addAll(mapInternalLogsByHash.values());
        insertLog(logs);
    }

    private Boolean isPassthroughMode() {
        return ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c && String.isNotBlank(ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Email__c);
    }

    private List<Log__c> getLogs(Set<String> setAsyncApexJobIds) {
        String query = new QBuilder(Log__c.SObjectType)
                .selectFields(new Set<String>{'Id', 'Async_Job_Id__c', 'Details__c', 'Hash__c'})
                .add(QBuilder.condition(Log__c.Async_Job_Id__c.getDescribe().getName()).isIn(new List<String>(setAsyncApexJobIds)))
                .build();
        query += ' ALL ROWS';
        return (List<Log__c>)JSON.deserialize(JSON.serialize(runQuery(ConnectedOrgService.getPassthroughConnectedOrg(), query)), List<Log__c>.class);
    }

    private Log__c createLog(AsyncApexJob asyncApexJob, Boolean isInternal) {
        return LogBuilder.getInstance()
                .category(isInternal ? Logger.CATEGORY_PHAROS_ERROR : 'Apex')
                .summary(asyncApexJob.ExtendedStatus)
                .details('Class: ' + asyncApexJob.ApexClass.Name + '\n' + asyncApexJob.ExtendedStatus)
                .area(isInternal ? Logger.AREA_PHAROS_ERROR : getArea(asyncApexJob.ExtendedStatus))
                .type(asyncApexJob.JobType)
                .attribute(Schema.SObjectType.Log__c.fields.Organization_Id__c.Name, corg.Name)
                .attribute(Schema.SObjectType.Log__c.fields.Organization_Name__c.Name, corg.Title__c)
                .attribute(Schema.SObjectType.Log__c.fields.Organization_Url__c.Name, corg.Instance_Url__c)
                .attribute(Schema.SObjectType.Log__c.fields.Async_Job_Id__c.Name, asyncApexJob.Id)
                .attribute(Schema.SObjectType.Log__c.fields.Async_Job_Name__c.Name, asyncApexJob.ApexClass.Name)
                .attribute(Schema.SObjectType.Log__c.fields.Apex_Name__c.Name, asyncApexJob.ApexClass.Name)
                .attribute(Schema.SObjectType.Log__c.fields.Hash__c.Name, LogService.generateHash_0(asyncApexJob.ApexClass.Name + asyncApexJob.ExtendedStatus + asyncApexJob.JobType + asyncApexJob.Status))
                .attribute(Schema.SObjectType.Log__c.fields.Hash_1__c.Name, LogService.generateHash_1(asyncApexJob.ApexClass.Name + asyncApexJob.ExtendedStatus + asyncApexJob.JobType))
                .attribute(Schema.SObjectType.Log__c.fields.Hash_2__c.Name, LogService.generateHash_2(asyncApexJob.ApexClass.Name + asyncApexJob.ExtendedStatus))
                .attribute(Schema.SObjectType.Log__c.fields.Hash_3__c.Name, LogService.generateHash_3(asyncApexJob.ApexClass.Name))
                .build();
    }

    public void insertLog(List<Log__c> lstLogs) {
        if (isPassthroughMode()) {
            PassthroughtModeService.sendLogs(lstLogs);
        } else {
            PermissionsUtil.performUpsertDML(lstLogs, Schema.SObjectType.Log__c);
        }
    }

    private String getArea(String extendedStatus) {
        String area = 'Background Jobs';
        if (String.isNotBlank(extendedStatus)) {
            Matcher matcher = ConfigUtil.SOBJECT_ID_PATTERN.matcher(extendedStatus);
            while (matcher.find()) {
                try {
                    Id temporaryId = Id.valueOf(matcher.group());
                    area = temporaryId.getSobjectType().getDescribe().getName();
                    break;
                } catch (Exception e) {
                }
            }
        }
        return area;
    }

    private String getHash(AsyncApexJob asyncApexJob) {
        return LogService.generateHash_0(asyncApexJob.ApexClass.Name + asyncApexJob.ExtendedStatus + asyncApexJob.JobType + asyncApexJob.Status);
    }

    private Map<Id, ApexClass> getInternalApexClasses(Set<String> setApexClassIdIds) {
        return new Map<Id, ApexClass>([SELECT Id FROM ApexClass WHERE Id IN :setApexClassIdIds AND NamespacePrefix = :ConfigUtil.getNameSpace()]);
    }

    private List<Object> runQuery(Connected_Org__c corg, String q) {
        return isPassthroughMode() ? HttpUtils.runToolingQuery(corg.Instance_Url__c, ConnectedOrgService.getConnectedOrgAccessToken(corg), q) : Database.query(q);
    }

}