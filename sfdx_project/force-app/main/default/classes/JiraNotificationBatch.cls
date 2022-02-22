public with sharing class JiraNotificationBatch implements Database.batchable<Sobject>,Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents{

    public JiraNotificationBatch() {}

    public Database.QueryLocator start(Database.BatchableContext bc) {
        JiraService.validateAndRefreshJiraOauthToken(false);
        GraphAPIService.validateAndRefreshGraphApiOauthToken();
        upsert ConfigUtil.JIRA_SETTINGS;
        upsert ConfigUtil.GRAPH_API_SETTINGS;


        Database.QueryLocator queryLocator = Database.getQueryLocator([
            SELECT Id, Jira_Integration_Status__c, Notification_Integration_Status__c
            FROM Log__c
            WHERE Jira_Integration_Status__c = :MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING
                OR Notification_Integration_Status__c = :MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING
            ORDER BY Created_At__c
        ]);
        return queryLocator;
    }

    public void execute(Database.batchableContext info, List<SObject> scope) {
        List<Log__c> scopeLogs = (List<Log__c>)scope;
        executeNotificationRules(scopeLogs);
    }

    public static final List<String> BATCH_LOCATOR_ADDITIONAL_SYSTEM_FIELDS = new List<String>{'Hash_1__c','Organization_Id__c','Bug_Tracker__c','Hash_2__c','Hash_3__c','Jira_Integration_Status__c','Notification_Integration_Status__c'};

    private void executeNotificationRules(List<Log__c> scopeLogs) {
        Map<Id, List<System.Exception>> emailExceptions = new Map<Id, List<System.Exception>>();
        Map<Id, List<System.Exception>> slackExceptions = new Map<Id, List<System.Exception>>();
        Map<Id, List<System.Exception>> pagerDutyExceptions = new Map<Id, List<System.Exception>>();
        Map<Id, List<System.Exception>> teamsExceptions = new Map<Id, List<System.Exception>>();
        Map<Id, System.Exception> jiraFieldUpdateExceptions = new Map<Id, System.Exception>();
        Map<Id, Log__c> toUpdateMap = new Map<Id, Log__c>();
        String jiraIssueKey;

        if(!scopeLogs.isEmpty()) {
            List<MonitoringUtil.MonitoringRule> notificationRules = MonitoringUtil.getNotificationRules(null);
            List<MonitoringUtil.MonitoringRule> jiraRules = MonitoringUtil.getJiraRules(null);

            List<String> logFields = MonitoringUtil.getLogFieldNames(notificationRules);
            List<String> jiraLogFields = MonitoringUtil.getLogFieldNames(jiraRules);
            logFields.addAll(BATCH_LOCATOR_ADDITIONAL_SYSTEM_FIELDS);
            logFields.addAll(jiraLogFields);
            String query = new QBuilder(Log__c.SObjectType)
                .selectFields(new Set<String>(logFields))
                .add(QBuilder.condition('Id').equalsTo(scopeLogs.get(0).Id))
                .build();
            List<Log__c> logs = Database.query(query);

            Log__c emailLog;
            Action__c emailAction;

            for(Log__c log : logs) {
                Boolean fireOnlyFirstEvaluatedRule = false;

                for(MonitoringUtil.MonitoringRule rule : notificationRules) {
                    if(fireOnlyFirstEvaluatedRule) break;

                    Set<Id> firedIds = rule.applyNotificationRules(new List<Log__c>{log});
                    if(firedIds.contains(log.Id)) {
                        fireOnlyFirstEvaluatedRule = true;
                        for(MonitoringUtil.Action action : rule.actions) {
                            switch on MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(action.type) {
                                when EMAIL {
                                    emailLog = log;
                                    emailAction = action.fields;
                                }
                                when SLACK {
                                    try {
                                        sendSlack(log, action.fields, rule.ruleId);
                                    }
                                    catch(Exception e) {
                                        List<System.Exception> exceptions = slackExceptions.get(log.Id) != null
                                            ? slackExceptions.get(log.Id)
                                            : new List<System.Exception>();
                                        exceptions.add(e);
                                        slackExceptions.put(log.Id, exceptions);
                                    }
                                }
                                when TEAMS {
                                    try {
                                        sendTeams(log, action.fields, rule.ruleId);
                                    }
                                    catch(Exception e) {
                                        List<System.Exception> exceptions = teamsExceptions.get(log.Id) != null
                                                ? teamsExceptions.get(log.Id)
                                                : new List<System.Exception>();
                                        exceptions.add(e);
                                        teamsExceptions.put(log.Id, exceptions);
                                    }
                                }
                                when PAGERDUTY {
                                    try {
                                        sendPagerDuty(log, action.fields);
                                    }
                                    catch(Exception e) {
                                        List<System.Exception> exceptions = pagerDutyExceptions.get(log.Id) != null
                                            ? pagerDutyExceptions.get(log.Id)
                                            : new List<System.Exception>();
                                        exceptions.add(e);
                                        pagerDutyExceptions.put(log.Id, exceptions);
                                    }
                                }
                            }
                        }
                    }
                }
                if(!fireOnlyFirstEvaluatedRule) {
                    Log__c failedLog = new Log__c(Id = log.Id);
                    failedLog.Notification_Integration_Status__c = MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_FAILED;
                    toUpdateMap.put(log.Id, failedLog);
                }

                for(MonitoringUtil.MonitoringRule rule : jiraRules) {
                    if(String.isNotBlank(jiraIssueKey)) break;

                    Set<Id> firedIds = rule.applyNotificationRules(new List<Log__c>{log});
                    if(firedIds.contains(log.Id)) {
                        for(MonitoringUtil.Action action : rule.actions) {
                            switch on MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(action.type) {
                                when JIRA {
                                    try {
                                        // send only first jira action
                                        if(String.isBlank(jiraIssueKey)) {
                                            jiraIssueKey = sendJira(log, action.fields);
                                        }
                                    }
                                    catch(Exception e) {
                                        jiraFieldUpdateExceptions.put(log.Id, e);
                                    }
                                }
                            }
                        }
                    }
                }
                if(jiraIssueKey == null && !jiraRules.isEmpty() && log.Jira_Integration_Status__c == MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING) {
                    Log__c failedLog = (toUpdateMap.containsKey(log.Id)) ? toUpdateMap.get(log.Id) : new Log__c(Id = log.Id);
                    failedLog.Bug_Tracker__c = null;
                    failedLog.Jira_Integration_Status__c = ConfigUtil.TICKET_CREATE_ERROR_STATUS;
                    toUpdateMap.put(log.Id, failedLog);
                }
            }

            // send email after all callouts
            // avoid System.CalloutException: You have uncommitted work pending. Please commit or rollback before calling out
            if(emailLog != null && emailAction != null) {
                try {
                    sendEmail(emailLog, emailAction);
                }
                catch(Exception e) {
                    List<System.Exception> exceptions = emailExceptions.get(emailLog.Id) != null
                        ? emailExceptions.get(emailLog.Id)
                        : new List<System.Exception>();
                    exceptions.add(e);
                    emailExceptions.put(emailLog.Id, exceptions);
                }
            }

            if(!jiraFieldUpdateExceptions.isEmpty()) {
                setErrorJiraStatus(new List<Log__c>{logs.get(0)});
            }
            else if(String.isNotEmpty(jiraIssueKey) || jiraIssueKey == '') {
                List<Log__c> sameOpenLogsByHash1 = JiraService.getSameOpenLogsByHash1(logs.get(0));
                if(!sameOpenLogsByHash1.isEmpty()) {
                    List<Log__c> logsWithHash1 = JiraService.getOtherLogsWithHash1AndEmptyBugTrackerLink(logs.get(0));
                    logsWithHash1.add(new Log__c(Id = logs.get(0).Id, Bug_Tracker__c = null));
                    for(Log__c l : logsWithHash1) {
                        if(String.isBlank(l.Bug_Tracker__c)) {
                            l.Bug_Tracker__c = sameOpenLogsByHash1.get(0).Bug_Tracker__c;
                            l.Jira_Integration_Status__c = ConfigUtil.EXISTING_TICKET_LINKED_STATUS;
                        }
                    }
                    update logsWithHash1;
                }
            }

            for(Log__c log : logs) {
                Log__c logUpd = toUpdateMap.containsKey(log.Id) ? toUpdateMap.get(log.Id) : new Log__c(Id = log.Id);
                List<System.Exception> emailExceptionsList = emailExceptions.get(log.Id);
                List<System.Exception> slackExceptionsList = slackExceptions.get(log.Id);
                List<System.Exception> pagerDutyExceptionsList = pagerDutyExceptions.get(log.Id);
                List<System.Exception> teamsExceptionsList = teamsExceptions.get(log.Id);

                if((emailExceptionsList == null || emailExceptionsList.isEmpty())
                    && (teamsExceptionsList == null || teamsExceptionsList.isEmpty())
                    && (slackExceptionsList == null || slackExceptionsList.isEmpty())
                    && (pagerDutyExceptionsList == null || pagerDutyExceptionsList.isEmpty())) {
                    logUpd.Notification_Integration_Status__c = MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_COMPLETED;
                }
                else {
                    logUpd.Email_Integration_Status__c = (emailExceptionsList != null && !emailExceptionsList.isEmpty())
                        ? emailExceptionsList.get(0).getMessage().abbreviate(ConfigUtil.MAX_LENGTH_TEXT_FIELD)
                        : null;
                    logUpd.PagerDuty_Integration_Status__c = (pagerDutyExceptionsList != null && !pagerDutyExceptionsList.isEmpty())
                        ? pagerDutyExceptionsList.get(0).getMessage().abbreviate(ConfigUtil.MAX_LENGTH_TEXT_FIELD)
                        : null;
                    logUpd.Slack_Integration_Status__c = (slackExceptionsList != null && !slackExceptionsList.isEmpty())
                        ? slackExceptionsList.get(0).getMessage().abbreviate(ConfigUtil.MAX_LENGTH_TEXT_FIELD)
                        : null;
                    logUpd.Teams_Integration_Status__c = (teamsExceptionsList != null && !teamsExceptionsList.isEmpty())
                        ? teamsExceptionsList.get(0).getMessage().abbreviate(ConfigUtil.MAX_LENGTH_TEXT_FIELD)
                        : null;
                    logUpd.Notification_Integration_Status__c = MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_FAILED;
                }
                toUpdateMap.put(log.Id, logUpd);
            }

            if(!toUpdateMap.isEmpty()) {
                update toUpdateMap.values();
            }
        }
    }

    public void sendEmail(Log__c log, Action__c action) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (action.EmailTemplateId__c != null && action.Contact__c != null) {
            mail.setTargetObjectId(action.Contact__c);
            mail.setTemplateId(action.EmailTemplateId__c);
            mail.setWhatId(log.Id);
        }
        else {
            mail.setBccSender(false);
            mail.setUseSignature(false);
            mail.setSubject(NotificationBatch.renderMergeFields(action.Subject__c, log.Id));
            mail.setHtmlBody(NotificationBatch.renderMergeFields(action.EmailBody__c, log.Id));
            mail.setToAddresses(new List<String>{action.EmailTo__c});
        }
        if (action.EmailCC__c != null)  mail.setCcAddresses(new List<String>{action.EmailCC__c});
        if (!Test.isRunningTest()) Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    public void sendTeams(Log__c log, Action__c action, String ruleId) {
        if(!PermissionsUtil.TeamsIntegrationEnabled || !ConfigUtil.GRAPH_API_SETTINGS.Enabled__c) return;

        GraphAPIService.GraphApiSetting settings = new GraphAPIService.GraphApiSetting(action.Team_Id__c, action.Channel_Id__c);
        String subject = NotificationBatch.renderMergeFields(action.Subject__c, log.Id);
        String body = NotificationBatch.renderMergeFields(action.Body__c, log.Id);
        GraphAPIService.ChatMessage chatMessage = new GraphAPIService.ChatMessage(subject, body);
        GraphAPIService.sendChannelMessage(settings.teamId, settings.channelId, chatMessage);
    }


    public void sendSlack(Log__c log, Action__c action, String ruleId) {
        if(!PermissionsUtil.SlackIntegrationEnabled) return;

        if(!SlackService.isValidChannel(action.SlackChannels__c)) {
            throw new SlackService.SlackServiceException('Unable to send slack notification to channel ' + action.SlackChannels__c + '. Please check notifications rule ' + ruleId + ' settings.');
        }

        String subject = NotificationBatch.renderMergeFields(action.Subject__c, log.Id);
        String body = NotificationBatch.renderMergeFields(action.Body__c, log.Id);
        String message = subject + ConfigUtil.NEW_LINE_CARRIAGE_RETURN + body;
        SlackService.sendMessageToSlack(message, action.SlackChannels__c);
    }

    public void sendPagerDuty(Log__c log, Action__c action) {
        if(!PermissionsUtil.PagerDutyIntegrationEnabled) return;

        String subject = NotificationBatch.renderMergeFields(action.Subject__c, log.Id);
        String body = NotificationBatch.renderMergeFields(action.Body__c, log.Id);

        if (action.PagerDuty_Type__c == 'Incident')
            PagerDutyService.createIncident(subject,  body);
        else if (action.PagerDuty_Type__c == 'Event')
            PagerDutyService.createEvent(log.Id, subject,  body);
    }

    public String sendJira(Log__c log, Action__c action) {
        String issueKey = JiraService.createTaskFromLogWithAction(log.Id, action);
        return issueKey;
    }

    private static void setErrorJiraStatus(List<Log__c> scopeLogs) {
        for(Log__c log : scopeLogs) {
            log.Bug_Tracker__c = null;
            log.Jira_Integration_Status__c = ConfigUtil.TICKET_CREATE_ERROR_STATUS;
        }
        update scopeLogs;
    }

    public void finish(Database.batchableContext info) {
        List<Log__c> logs = [
            SELECT Id
            FROM Log__c
            WHERE Jira_Integration_Status__c = :MonitoringUtil.JIRA_INTEGRATION_STATUS_PENDING
                OR Notification_Integration_Status__c = :MonitoringUtil.NOTIFICATION_INTEGRATION_STATUS_PENDING
            LIMIT 1
        ];
        if(!logs.isEmpty() && !Test.isRunningTest()) {
            Database.executeBatch(new JiraNotificationBatch(), 1);
        }
    }
}