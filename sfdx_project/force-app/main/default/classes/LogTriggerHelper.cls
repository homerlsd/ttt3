public with sharing class LogTriggerHelper {

    @TestVisible
    private static Datetime currentTime = Datetime.now();

    public static void populateDefaults(List<Log__c> newLogs) {
        for (Log__c log : newLogs) {
            if (!isBroadcastLog(log, null) && !isInternalErrorLog(log, null)){

                if (String.isBlank(log.Post_Processing_Status__c)) log.Post_Processing_Status__c = LogPostProcessingService.POST_PROCESSING_STATUS_NEEDED;
                if (String.isBlank(log.Deploy_Results__c)) log.Deploy_Results__c = LogPostProcessingService.ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
                if (String.isBlank(log.Setup_Audit_Trail__c)) log.Setup_Audit_Trail__c = LogPostProcessingService.ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
                if (String.isBlank(log.Pending_Jobs__c)) log.Pending_Jobs__c = LogPostProcessingService.ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
                if (String.isBlank(log.Installed_Packages__c)) log.Installed_Packages__c = LogPostProcessingService.ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
                if (String.isBlank(log.Stacktrace_Parse_Result__c)) log.Stacktrace_Parse_Result__c = LogPostProcessingService.ERROR_SYSTEM_INFO_LOG_NOT_AVAILABLE;
            }
        }
    }

    public static Boolean isBroadcastLog(Log__c newLog, Log__c oldLog) {
        if(newLog.Originated_From__c == ConfigUtil.ORIGINATED_FROM_BROADCAST && oldLog == null) {
            return true;
        }
        return false;
    }

    public static Boolean isInternalErrorLog(Log__c newLog, Log__c oldLog) {
        if(newLog.Category__c == Logger.CATEGORY_PHAROS_ERROR && newLog.Area__c == Logger.AREA_PHAROS_ERROR) {
            return true;
        }
        return false;
    }

    public static Boolean isRegularErrorLogPostprocessingCompleted(Log__c newLog, Log__c oldLog) {
        if(oldLog != null
            && newLog.Post_Processing_Status__c != oldLog.Post_Processing_Status__c
            && newLog.Post_Processing_Status__c == LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED) {
            return true;
        }
        return false;
    }

    public static Boolean isErrorLogNotificationsPending(Log__c newLog, Log__c oldLog) {
        if(oldLog != null
            && ((oldLog.Jira_Integration_Status__c != newLog.Jira_Integration_Status__c
                    && newLog.Jira_Integration_Status__c == MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING)
                || (oldLog.Notification_Integration_Status__c != newLog.Notification_Integration_Status__c
                    && newLog.Notification_Integration_Status__c == MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING)
                )) {
            return true;
        }
        return false;
    }

    public static Boolean isRunningNotifications(Log__c newLog, Log__c oldLog) {
        if(newLog.Jira_Integration_Status__c == MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING
            || newLog.Notification_Integration_Status__c == MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING
            || (oldLog != null
                && (oldLog.Jira_Integration_Status__c == MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING
                    || oldLog.Notification_Integration_Status__c == MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING))) {
            return true;
        }
        return false;
    }


    public static void runNotificationRules(List<Log__c> newLogs, Map<Id, Log__c> oldLogsMap) {
        List<Log__c> completedLogs = new List<Log__c>();
        for(Log__c log : newLogs) {
            Log__c oldLog = oldLogsMap != null ? oldLogsMap.get(log.Id) : null;

            // skip started notifications
            if(isRunningNotifications(log, oldLog)) continue;

            if(isBroadcastLog(log, oldLog)
                || isRegularErrorLogPostprocessingCompleted(log, oldLog)
                || (PermissionsUtil.NotificationForPharosErrors && isInternalErrorLog(log, oldLog))) {

                completedLogs.add(log);
            }
        }
        if(!completedLogs.isEmpty()) {
            List<MonitoringUtil.MonitoringRule> notificationRules = MonitoringUtil.getNotificationRules(null);
            MonitoringUtil.assignNotificationRules(notificationRules, completedLogs);

            if(PermissionsUtil.JiraIntegrationEnabled) {
                List<MonitoringUtil.MonitoringRule> jiraRules = MonitoringUtil.getJiraRules(null);
                MonitoringUtil.assignNotificationRules(jiraRules, completedLogs, true);
            }
        }
    }

    public static void executeNotificationRules(List<Log__c> newLogs, Map<Id, Log__c> oldLogsMap) {
        Boolean hasNotificationLogs = false;

        for(Log__c log : newLogs) {
            Log__c oldLog = oldLogsMap != null ? oldLogsMap.get(log.Id) : null;

            if(isErrorLogNotificationsPending(log, oldLog)) {
                hasNotificationLogs = true;
                break;
            }
        }

        if(hasNotificationLogs) {
            List<AsyncApexJob> currentJobs = [
                SELECT Id, JobType, ApexClassID, ApexClass.Name, Status
                FROM AsyncApexJob
                WHERE Status IN ('Processing','Preparing','Queued', 'Holding') AND
                    JobType != 'BatchApexWorker' AND
                    ApexClass.Name = 'JiraNotificationBatch'
                LIMIT 1
            ];
            
            if(currentJobs.isEmpty() && !System.isFuture()) {
                try {
                    Database.executeBatch(new JiraNotificationBatch(), 1);
                }
                catch(Exception e){}

            }
        }
    }

    public static Boolean needRunMonitoringRules() {
        Boolean needRunBatch = false;

        List<Id> monitoringRuleIds = new List<Id>();
        List<MonitoringUtil.MonitoringRule> monitoringRules = MonitoringUtil.getMonitoringRules(null);
        Map<Id, MonitoringUtil.Event> monitoringEventsMap = MonitoringUtil.getLastCreatedEventsMap();

        DateTime lastProcessedDatetime = null;
        for(MonitoringUtil.MonitoringRule monitoringRule : monitoringRules) {
            MonitoringUtil.Event monitoredEvent = monitoringEventsMap.get(monitoringRule.ruleId);

            if(monitoredEvent == null) {
                monitoringRuleIds.add(monitoringRule.ruleId);
            }
            else if (monitoredEvent.createdDate != null
                    && (monitoringRule.nextRunTime(monitoredEvent.createdDate) <= currentTime)
                    || monitoringRule.nextRunTime(monitoredEvent.createdDate) == null) {

                monitoringRuleIds.add(monitoringRule.ruleId);
                lastProcessedDatetime = (monitoredEvent.createdDate < lastProcessedDatetime && lastProcessedDatetime != null)
                        ? monitoredEvent.createdDate
                        : (lastProcessedDatetime == null ? monitoredEvent.createdDate : lastProcessedDatetime);
            }
        }

        if(!monitoringRuleIds.isEmpty()) {

            if(lastProcessedDatetime == null) {
                // run batch
                needRunBatch = true;
            }
            else {
                // count recordsnextRunTime
                String query = new QBuilder(Log__c.SObjectType)
                    .selectFields(new Set<String>{'count()'})
                    .add(QBuilder.condition('Created_At__c').isGreaterOrEquals(':lastProcessedDatetime'))
                    .add(!PermissionsUtil.NotificationForPharosErrors ? QBuilder.condition('Category__c').notEqualsTo(Logger.CATEGORY_PHAROS_ERROR) : null)
                    .add(!PermissionsUtil.NotificationForPharosErrors ? QBuilder.condition('Area__c').notEqualsTo(Logger.AREA_PHAROS_ERROR) : null)
                    .build();
                Integer countLogs = Database.countQuery(query);

                if(countLogs > 0) {
                    // run batch
                    needRunBatch = true;
                }
            }
        }
        return needRunBatch;
    }

    public static void runMonitoringRules() {
        if(needRunMonitoringRules()) {
            MonitoringBatch.startMonitoringBatch();
        }
    }

    public static void updateLastCreatedLogFlag(List<Log__c> newLogs) {
        DateTime maxCratedDateTime = newLogs.get(0).CreatedDate;
        for(Log__c log : newLogs) {
            if(log.CreatedDate > maxCratedDateTime) {
                maxCratedDateTime = log.CreatedDate;
            }
        }
        updateLastCreatedLogFlag(maxCratedDateTime);
    }

    public static void updateLastCreatedLogFlag(DateTime lastCreatedLogDateTime) {
        Monitoring_Batch_Flag__c flag = Monitoring_Batch_Flag__c.getOrgDefaults();
        if(Schema.sObjectType.Monitoring_Batch_Flag__c.fields.Last_Created_Log__c.isCreateable()
            && Schema.sObjectType.Monitoring_Batch_Flag__c.fields.Last_Created_Log__c.isUpdateable()) {
            flag.Last_Created_Log__c = lastCreatedLogDateTime;
        }
        if(Schema.sObjectType.Monitoring_Batch_Flag__c.isAccessible()
            && Schema.sObjectType.Monitoring_Batch_Flag__c.isCreateable()
            && Schema.sObjectType.Monitoring_Batch_Flag__c.isUpdateable()) {
            upsert flag;
        }
    }

    public static void updateLastProcessedLogFlag(DateTime lastProcessedLogDateTime) {
        Monitoring_Batch_Flag__c flag = Monitoring_Batch_Flag__c.getOrgDefaults();
        if(Schema.sObjectType.Monitoring_Batch_Flag__c.fields.Last_Processed_Log__c.isCreateable()
            && Schema.sObjectType.Monitoring_Batch_Flag__c.fields.Last_Processed_Log__c.isUpdateable()) {
            flag.Last_Processed_Log__c = lastProcessedLogDateTime;
        }
        if(Schema.sObjectType.Monitoring_Batch_Flag__c.isAccessible()
            && Schema.sObjectType.Monitoring_Batch_Flag__c.isCreateable()
            && Schema.sObjectType.Monitoring_Batch_Flag__c.isUpdateable()) {
            upsert flag;
        }
    }

    public static void createContentDocumentLinks(List<Log__c> lstLogs) {
        Set<String> setAsyncJobIds = new Set<String>();
        for (Log__c log : lstLogs) {
            if (String.isNotBlank(log.Async_Job_Id__c)) {
                setAsyncJobIds.add(log.Async_Job_Id__c);
            }
        }
        if (!setAsyncJobIds.isEmpty()) {
            BulkAPIJobBatchService.createContentDocumentLinks(setAsyncJobIds);
        }
    }

    public static void sendToBroadcast(List<Log__c> lstLogs, Map<Id, Log__c> oldLogsMap) {
        List<Log__c> lstLogsWithPostProcessingComplete = new List<Log__c>();
        for (Log__c log : lstLogs) {
            if (String.isBlank(log.Originated_From__c)
                    && log.Post_Processing_Status__c == LogPostProcessingService.POST_PROCESSING_STATUS_COMPLETED
                    && oldLogsMap != null
                    && oldLogsMap.containsKey(log.Id)
                    && log.Post_Processing_Status__c != oldLogsMap.get(log.Id).Post_Processing_Status__c)
            {
                lstLogsWithPostProcessingComplete.add(log);
            }
        }
        if (!lstLogsWithPostProcessingComplete.isEmpty()) {
            BroadcastService.sendLogs(lstLogsWithPostProcessingComplete);
        }
    }

    public static void runPostProcessing(List<Log__c> newLogs) {
        Boolean exist = false;
        for (Log__c log : newLogs) {
            if (log.Post_Processing_Status__c == LogPostProcessingService.POST_PROCESSING_STATUS_NEEDED) {
                exist = true;
                break;
            }
        }
        List<AsyncApexJob> asyncApexJobs = [
                SELECT Id
                FROM AsyncApexJob
                WHERE Status IN ('Processing','Preparing','Queued', 'Holding')
                AND JobType != 'BatchApexWorker'
                AND ApexClass.Name = 'LogPostProcessingBatch'
                LIMIT 1
        ];
        if (exist && asyncApexJobs.isEmpty()) {
            try {
                if (!Test.isRunningTest()) {
                    Database.executeBatch(new LogPostProcessingBatch(), 1);
                }
            } catch (Exception e) {
                Logger.getInstance().internalError(e, null, true, LogTriggerHelper.class.getName(), 'runPostProcessing');
            }
        }
    }


    public static void deleteContentDocument(Map<Id, Log__c> oldLogsMap) {
        Set<String> setContentDocumentIds = new Set<String>();
        for (ContentDocumentLink contentDocumentLink : [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :oldLogsMap.keySet()]) {
            setContentDocumentIds.add(contentDocumentLink.ContentDocumentId);
        }
        List<ContentDocument> lstContentDocuments = [SELECT Id FROM ContentDocument WHERE Id IN :setContentDocumentIds];
        if (!lstContentDocuments.isEmpty()) {
            try {
                delete lstContentDocuments;
            }
            catch(Exception e) {
                Logger.getInstance().internalError(e, null, true,  LogTriggerHelper.class.getName(), 'deleteContentDocument');
            }
        }
    }
}