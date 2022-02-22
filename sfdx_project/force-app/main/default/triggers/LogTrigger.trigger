trigger LogTrigger on Log__c (after insert, before insert, before update, after update, before delete) {

    if(Trigger.isBefore && Trigger.isInsert) {
        LogTriggerHelper.populateDefaults(Trigger.new);
        LogService.copyLogFlagsFields(Trigger.new);
    }

    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        LogService.assignRecordTypes(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isBefore && Trigger.isUpdate) {
        LogTriggerHelper.sendToBroadcast(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        LogTriggerHelper.deleteContentDocument(Trigger.oldMap);
    }

    if(Trigger.isAfter && Trigger.isInsert) {
        LogTriggerHelper.updateLastCreatedLogFlag(Trigger.new);
        LogTriggerHelper.createContentDocumentLinks(Trigger.new);
        if (PermissionsUtil.MonitoringEnabled && ConfigUtil.SETTINGS.Monitoring_Enabled__c) {
            LogTriggerHelper.runMonitoringRules();
        }
        LogService.runAsyncMethods(Trigger.new);
        LogTriggerHelper.runPostProcessing(Trigger.new);
    }

    if(Trigger.isAfter && (Trigger.isUpdate || Trigger.isInsert)) {
        LogTriggerHelper.runNotificationRules(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isAfter && Trigger.isUpdate) {
        LogTriggerHelper.executeNotificationRules(Trigger.new, Trigger.oldMap);
    }
}