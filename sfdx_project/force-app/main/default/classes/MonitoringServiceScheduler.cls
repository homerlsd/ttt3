public with sharing class MonitoringServiceScheduler implements Schedulable{
    public void execute(SchedulableContext sc) {
        if (ConfigUtil.SETTINGS.Monitoring_Enabled__c == false) {
            return;
        }
        Database.executeBatch(new MonitoringBatch(), 1);
    }
}