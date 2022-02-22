public with sharing class LogPostProcessingBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, Database.RaisesPlatformEvents {

    @TestVisible
    private static Boolean testThrowUnhandledException = false;

    public Database.QueryLocator start(Database.BatchableContext info) {
        return Database.getQueryLocator([SELECT Id FROM Log__c WHERE Post_Processing_Status__c = :LogPostProcessingService.POST_PROCESSING_STATUS_NEEDED]);
    }

    private Map<Id, List<Exception>> exceptionMap = new Map<Id, List<Exception>>();
    private Set<Id> logIdsInTransaction = new Set<Id>();
    private Set<Id> successLogIdsInTransaction = new Set<Id>();

    public void execute(Database.BatchableContext BC, List<Log__c> scope) {
        this.logIdsInTransaction.add(scope[0].Id);
        try {
            List<Exception> exceptions = LogPostProcessingService.doLogPostProcessing(scope[0].Id);
            this.exceptionMap.put(scope[0].Id, exceptions);
            if(exceptions.isEmpty()) {
                successLogIdsInTransaction.add(scope[0].Id);
            }
        }
        catch (Exception e) {
            Logger.getInstance().internalError(e, scope[0].Id, true,  LogPostProcessingBatch.class.getName(), 'execute');
            PermissionsUtil.putSObjectField(scope[0], Schema.SObjectType.Log__c.fields.Post_Processing_Status__c, LogPostProcessingService.POST_PROCESSING_STATUS_FAILED);
            PermissionsUtil.performUpdateDML(new List<Log__c>{scope[0]}, Schema.SObjectType.Log__c);
        }
        this.logIdsInTransaction.remove(scope[0].Id);
    }

    public void finish(Database.BatchableContext BC) {
        // if set contains id, log transaction is failed with unexpected exception
        if(!this.logIdsInTransaction.isEmpty()) {
            for(Id logId : new List<Id>(this.logIdsInTransaction)) {
                List<Exception> exceptions = this.exceptionMap.get(logId) != null ? this.exceptionMap.get(logId) : new List<Exception>();
                exceptions.add(new System.LimitException());
                this.exceptionMap.put(logId, exceptions);
            }
        }
        List<Log__c> logsToCompleteFlag = new List<Log__c>();
        if(!this.exceptionMap.isEmpty()) {
            for(Id logId : this.exceptionMap.keySet()) {
                List<Exception> exceptions = this.exceptionMap.get(logId);
                Log__c log = (Log__c)PermissionsUtil.newSObject(Schema.sObjectType.Log__c);
                PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Id, logId);
                PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Post_Processing_Status__c, !exceptions.isEmpty() ? LogPostProcessingService.POST_PROCESSING_STATUS_FAILED : LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED);
                logsToCompleteFlag.add(log);
            }
        }
        for(Id logId : new List<Id>(this.successLogIdsInTransaction)) {
            if(this.exceptionMap.containsKey(logId)) continue;

            Log__c log = (Log__c)PermissionsUtil.newSObject(Schema.sObjectType.Log__c);
            PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Id, logId);
            PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Post_Processing_Status__c, LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED);
            logsToCompleteFlag.add(log);
        }

        if(!logsToCompleteFlag.isEmpty()) {
            PermissionsUtil.performUpdateDML(logsToCompleteFlag, Schema.SObjectType.Log__c);
        }

        List<Log__c> logs = [
            SELECT Id
            FROM Log__c
            WHERE Post_Processing_Status__c = :LogPostProcessingService.POST_PROCESSING_STATUS_NEEDED
                AND Id NOT IN :this.exceptionMap.keySet()
            LIMIT 1
        ];
        if (!logs.isEmpty()) {
            try {
                if (!Test.isRunningTest()) {
                    Database.executeBatch(new LogPostProcessingBatch(), 1);
                }
            } catch (Exception e) {
                Logger.getInstance().internalError(e, null, true, LogPostProcessingBatch.class.getName(), 'runPostProcessing');
            }
        }
        if (testThrowUnhandledException) {
            Integer i = 1/0;
        }
    }

}