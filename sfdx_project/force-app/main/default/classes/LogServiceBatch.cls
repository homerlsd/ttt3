public with sharing class LogServiceBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

    public LogServiceBatch() {}

    public Database.QueryLocator start(Database.BatchableContext BC){
        String query = 'SELECT Id, Name, Access_Token__c, Refresh_Token__c, Private_Key__c FROM Connected_Org__c';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Connected_Org__c> scope){
        for (Connected_Org__c corg : scope) {
            if (corg.Name == null || String.isBlank(corg.Access_Token__c) || String.isBlank(corg.Refresh_Token__c)) {
                continue;
            }
            try {
                corg = ConnectedOrgService.refreshToken(corg.Name);
            } catch (Exception e) {
                Logger.getInstance().internalError(e, corg.Name, true, LogServiceBatch.class.getName(), 'refreshToken');
            }
            try {
                PermissionsUtil.performUpdateDML(new List<Connected_Org__c>{corg}, Schema.SObjectType.Connected_Org__c);
            } catch (Exception e) {
                Logger.getInstance().internalError(e, corg.Name, true, LogServiceBatch.class.getName(), 'performUpdateDML');
            }
        }
    }

    public void finish(Database.BatchableContext BC) {}

}