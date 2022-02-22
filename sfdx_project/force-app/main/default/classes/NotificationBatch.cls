public with sharing class NotificationBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

    private static final String ERROR_MERGE_FIELDS_RENDERING = 'Error: unable to render merge fields, please check your syntax.';
    private Boolean IS_EXEPTION;

    public NotificationBatch() {
        IS_EXEPTION = false;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        JiraService.validateAndRefreshJiraOauthToken(false);
        GraphAPIService.validateAndRefreshGraphApiOauthToken();
        upsert ConfigUtil.JIRA_SETTINGS;
        upsert ConfigUtil.GRAPH_API_SETTINGS;

        Database.QueryLocator query = Database.getQueryLocator([
            SELECT Id, Executed_On__c,  Type__c,
                    Action__c, Event__c, Contents__c,
                    Action__r.Body__c, Action__r.Description__c, Action__r.EmailBody__c,
                    Action__r.EmailCC__c, Action__r.EmailTemplateId__c, Action__r.EmailTo__c,
                    Action__r.JIRAAssignee__c,Action__r.JIRAAssignee_Id__c,  Action__r.JIRAComponents__c,  Action__r.JIRAEpic__c,
                    Action__r.JIRAIssueType__c,  Action__r.JIRALabels__c,  Action__r.JIRAPriority__c,
                    Action__r.JIRAProject__c,  Action__r.SlackChannels__c,  Action__r.Subject__c,
                    Action__r.Team_Id__c,Action__r.Channel_Id__c,
                    Event__r.RecordCount__c, Event__r.Criteria__c, Response__c,
                    Event__r.Records__c, Event__r.Grouped_Field_Values__c,
                    Event__r.Rule__r.EventTimeInterval__c, Event__r.CreatedDate,
                    Action__r.PagerDuty_Type__c, Action__r.Contact__c
            FROM EventAction__c
            WHERE Executed_On__c = null AND Action__c != null
        ]);
        return query;
        return null;
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        EventAction__c eventAction = ((List<EventAction__c>)scope)[0];
        try {
            sendNotification(eventAction);
        }
        catch(Exception e) {
            PermissionsUtil.putSObjectField(eventAction, Schema.sObjectType.EventAction__c.fields.Response__c, e.getMessage());
            PermissionsUtil.performUpdateDML(new List<EventAction__c>{eventAction}, Schema.sObjectType.EventAction__c);
            IS_EXEPTION = true;
        }
        PermissionsUtil.putSObjectField(eventAction, Schema.sObjectType.EventAction__c.fields.Executed_On__c, DateTime.now());
        PermissionsUtil.performUpdateDML(new List<EventAction__c>{eventAction}, Schema.sObjectType.EventAction__c);
    }

    public void finish(Database.BatchableContext BC) {
        if (!IS_EXEPTION) MonitoringUtil.checkStartActionsBatch(false);
    }

    public void sendNotification(EventAction__c eventAction) {
        String actionType = eventAction.Action_Type__c != null ? eventAction.Action_Type__c : eventAction.Type__c;
        switch on MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(actionType) {
            when TEAMS {
                sendTeams(eventAction);
            }
            when EMAIL {
                sendEmail(eventAction);
            }
            when SLACK {
                sendSlack(eventAction);
            }
            when JIRA {
                sendJira(eventAction);
            }
            when PAGERDUTY {
                sendPagerDuty(eventAction);
            }
        }
    }

    public void sendEmail(EventAction__c eventAction) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (eventAction.Action__r.EmailTemplateId__c != null && eventAction.Action__r.Contact__c != null) {
            mail.setTargetObjectId(eventAction.Action__r.Contact__c);
            mail.setTemplateId(eventAction.Action__r.EmailTemplateId__c);
            mail.setWhatId(eventAction.Event__c);
        }
        else {
            mail.setBccSender(false);
            mail.setUseSignature(false);
            mail.setSubject(renderMergeFields(eventAction.Action__r.Subject__c, eventAction));
            mail.setHtmlBody(renderMergeFields(eventAction.Action__r.EmailBody__c, eventAction));
            mail.setToAddresses(new List<String>{eventAction.Action__r.EmailTo__c});
        }
        if (eventAction.Action__r.EmailCC__c != null)  mail.setCcAddresses(new List<String>{eventAction.Action__r.EmailCC__c});
        if (!Test.isRunningTest()) Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    public void sendSlack(EventAction__c eventAction) {
        if(!PermissionsUtil.SlackIntegrationEnabled) return;

        if(!SlackService.isValidChannel(eventAction.Action__r.SlackChannels__c)) {
            throw new SlackService.SlackServiceException('Unable to send slack notification to channel ' + eventAction.Action__r.SlackChannels__c + '. Please check notifications rule ' + eventAction.Event__r.Rule__c + ' settings.');
        }

        String subject = renderMergeFields(eventAction.Action__r.Subject__c, eventAction);
        String body = renderMergeFields(eventAction.Action__r.Body__c, eventAction);
        String message = subject + '\r\n' + body;
        SlackService.sendMessageToSlack(message, eventAction.Action__r.SlackChannels__c);
    }

    public void sendTeams(EventAction__c eventAction) {
        if(!PermissionsUtil.TeamsIntegrationEnabled || !ConfigUtil.GRAPH_API_SETTINGS.Enabled__c) return;

        GraphAPIService.GraphApiSetting settings = new GraphAPIService.GraphApiSetting(eventAction.Action__r.Team_Id__c, eventAction.Action__r.Channel_Id__c);

        String subject = renderMergeFields(eventAction.Action__r.Subject__c, eventAction);
        String body = renderMergeFields(eventAction.Action__r.Body__c, eventAction);
        GraphAPIService.ChatMessage chatMessage = new GraphAPIService.ChatMessage(subject, body);
        GraphAPIService.sendChannelMessage(settings.teamId, settings.channelId, chatMessage);
    }

    public static String renderMergeFields(String msg, EventAction__c eventAction) {
        String message = msg;
        if(String.isNotBlank(message) && message.contains('{!')) {
            List<Messaging.RenderEmailTemplateBodyResult> resList =
                    Messaging.renderEmailTemplate(eventAction.Action__c, eventAction.Event__c, new List<String> {message});
            if(!resList.isEmpty()) {
                Messaging.RenderEmailTemplateBodyResult res = resList.get(0);
                if(res.getSuccess()) {
                    message = res.getMergedBody();
                }
                else {
                    message = ERROR_MERGE_FIELDS_RENDERING;
                }
            }
        }
        return message;
    }

    public static String renderMergeFields(String msg, Id logId) {
        String message = msg;
        if(String.isNotBlank(message) && message.contains('{!')) {
            List<Messaging.RenderEmailTemplateBodyResult> resList =
                    Messaging.renderEmailTemplate(UserInfo.getUserId(), logId, new List<String> {message});
            if(!resList.isEmpty()) {
                Messaging.RenderEmailTemplateBodyResult res = resList.get(0);
                if(res.getSuccess()) {
                    message = res.getMergedBody();
                }
                else {
                    message += '\r\n' + ERROR_MERGE_FIELDS_RENDERING;
                }
            }
        }
        return message;
    }

    public void sendJira(EventAction__c eventAction) {
        if(!PermissionsUtil.JiraIntegrationEnabled) return;

        JiraService.NewTaskCreatedResponse response = JiraService.createTaskFromNotification(eventAction);
        PermissionsUtil.putSObjectField(eventAction, Schema.sObjectType.EventAction__c.fields.Response__c, response.self);
        PermissionsUtil.putSObjectField(eventAction, Schema.sObjectType.EventAction__c.fields.Delivered_to__c,ConfigUtil.EVENT_ACTION_DELIVERED_TO_JIRA + ' ' + ConfigUtil.JIRA_TASK_URL + response.key);
        PermissionsUtil.performUpdateDML(new List<EventAction__c>{eventAction}, Schema.sObjectType.EventAction__c);
    }

    public void sendPagerDuty(EventAction__c eventAction) {
        if(!PermissionsUtil.PagerDutyIntegrationEnabled) return;

        String subject = renderMergeFields(eventAction.Action__r.Subject__c, eventAction);
        String body = renderMergeFields(eventAction.Action__r.Body__c, eventAction);

        if (eventAction.Action__r.PagerDuty_Type__c == 'Incident')
            PagerDutyService.createIncident(subject,  body);
        else if (eventAction.Action__r.PagerDuty_Type__c == 'Event')
            PagerDutyService.createEvent(eventAction.Id, subject,  body);
    }
}