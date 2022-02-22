public with sharing class RuleTriggerHelper {

    public static void validateRuleFiltersHandler(List<RuleFilter__c> ruleFilters) {
        List<Id> ruleIds = new List<Id>();
        for(RuleFilter__c ruleFilter : ruleFilters) {
            ruleIds.add(ruleFilter.Rule__c);
        }
        if(!ruleIds.isEmpty()) {
            validateRuleFilters(ruleIds.get(0));
        }
    }

    public static void validateRuleFilters(Id ruleId) {
        List<Rule__c> toUpdate = new List<Rule__c>();
        List<MonitoringUtil.MonitoringRule> rules = getRules(new List<Id>{ruleId});
        Boolean ruleNotValid = false;

        if(rules.get(0).ruleType == MonitoringUtil.RULE_TYPE_ARCHIVAL) {
            try {
                DateTime lastProcessedDatetime = DateTime.now();
                DateTime ruleStartTime = Datetime.now();
                List<String> logFields = MonitoringUtil.getLogFieldNames(rules);
                QBuilder qb = MonitoringBatch.getArchivalLogsQuery(rules.get(0), new Set<String>(logFields), lastProcessedDatetime, ruleStartTime);
                qb.addLimit(1);
                String qbQuery = qb.build();
                List<Log__c> logs = Database.query(qbQuery);
            }
            catch(Exception e) {
                ruleNotValid = true;
            }
            if(rules.get(0).filters == null || rules.get(0).filters.isEmpty()) {
                ruleNotValid = true;
            }
        }
        if(rules.get(0).ruleType == MonitoringUtil.RULE_TYPE_MONITORING) {
            try {
                DateTime lastProcessedDatetime = DateTime.now();
                QBuilder qbCount = MonitoringBatch.getMonitoringLogsQuery(rules.get(0), new Set<String>{'COUNT()'});
                String qbCountQuery = qbCount.build();
                Integer countLogs = Database.countQuery(qbCountQuery);

                List<String> logFields = MonitoringUtil.getLogFieldNames(rules);
                QBuilder qb = MonitoringBatch.getMonitoringLogsQuery(rules.get(0), new Set<String>(logFields));
                qb.addLimit(1);
                String qbQuery = qb.build();
                List<Log__c> logs = Database.query(qbQuery);
            }
            catch(Exception e) {
                ruleNotValid = true;
            }
        }
        if(rules.get(0).ruleType == MonitoringUtil.RULE_TYPE_JIRA_UPDATE) {
            try {
                List<MonitoringUtil.MonitoringRule> jiraRules = MonitoringUtil.getJiraRules(new List<Id>{rules.get(0).ruleId});
                List<String> jiraLogFields = MonitoringUtil.getLogFieldNames(jiraRules);
                jiraLogFields.addAll(JiraNotificationBatch.BATCH_LOCATOR_ADDITIONAL_SYSTEM_FIELDS);
                String query = new QBuilder(Log__c.SObjectType)
                    .selectFields(new Set<String>(jiraLogFields))
                    .addLimit(1)
                    .build();
                List<Log__c> logs = Database.query(query);
            }
            catch(Exception e) {
                ruleNotValid = true;
            }
        }
        if(rules.get(0).ruleType == MonitoringUtil.RULE_TYPE_NOTIFICATION) {
            try {
                List<MonitoringUtil.MonitoringRule> notificationRules = MonitoringUtil.getNotificationRules(new List<Id>{rules.get(0).ruleId});
                List<String> logFields = MonitoringUtil.getLogFieldNames(notificationRules);
                logFields.addAll(JiraNotificationBatch.BATCH_LOCATOR_ADDITIONAL_SYSTEM_FIELDS);
                String query = new QBuilder(Log__c.SObjectType)
                    .selectFields(new Set<String>(logFields))
                    .addLimit(1)
                    .build();
                List<Log__c> logs = Database.query(query);
            }
            catch(Exception e) {
                ruleNotValid = true;
            }
        }
        if(rules.get(0).ruleType == null) {
            ruleNotValid = true;
        }
        Boolean isNotValidRuleFields = isRuleNotValid(rules.get(0));
        if(isNotValidRuleFields && !ruleNotValid) {
            ruleNotValid = isNotValidRuleFields;
        }
        toUpdate.add(new Rule__c(Id = rules.get(0).ruleId, Is_Not_Valid__c = ruleNotValid));
        update toUpdate;
    }

    public static void validateRulesHandlerOnInsert(List<Rule__c> rules, Map<Id, Rule__c> oldRulesMap) {
        List<Id> ruleIds = new List<Id>();
        for(Rule__c rule : rules) {
            ruleIds.add(rule.Id);
        }
        if(!ruleIds.isEmpty()) {
            validateRules(ruleIds);
        }
    }

    public static void validateRulesHandlerOnUpdate(List<Rule__c> rules, Map<Id, Rule__c> oldRulesMap) {
        List<Id> ruleIds = new List<Id>();
        for(Rule__c rule : rules) {
            Rule__c oldRule = oldRulesMap.get(rule.Id);
            if(rule.EventTimeInterval__c != oldRule.EventTimeInterval__c
                || rule.Subtype__c != oldRule.Subtype__c
                || rule.Threshold__c != oldRule.Threshold__c
                || rule.Type__c != oldRule.Type__c
                || rule.Active__c != oldRule.Active__c) {

                ruleIds.add(rule.Id);
            }
        }
        if(!ruleIds.isEmpty()) {
            validateRules(ruleIds);
        }
    }

    public static void validateRules(List<Id> ruleIds) {
        List<Rule__c> toUpdate = new List<Rule__c>();
        List<MonitoringUtil.MonitoringRule> rules = getRules(ruleIds);

        for(MonitoringUtil.MonitoringRule monitoringRule : rules) {
            Boolean ruleNotValid = isRuleNotValid(monitoringRule);
            toUpdate.add(new Rule__c(Id = monitoringRule.ruleId, Is_Not_Valid__c = ruleNotValid));
        }
        if(!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static Boolean isRuleNotValid(MonitoringUtil.MonitoringRule monitoringRule) {
        Boolean ruleNotValid = false;
        if(monitoringRule.ruleType == MonitoringUtil.RULE_TYPE_ARCHIVAL) {
            ruleNotValid = isNotValidArchivalRule(monitoringRule);
        }
        if(monitoringRule.ruleType == MonitoringUtil.RULE_TYPE_MONITORING) {
            ruleNotValid = isNotValidMonitoringRule(monitoringRule);
        }
        if(monitoringRule.ruleType == MonitoringUtil.RULE_TYPE_JIRA_UPDATE) {
            ruleNotValid = isNotValidJiraUpdateRule(monitoringRule);
        }
        if(monitoringRule.ruleType == MonitoringUtil.RULE_TYPE_NOTIFICATION) {
            ruleNotValid = isNotValidNotificationRule(monitoringRule);
        }
        return ruleNotValid;
    }

    public static Boolean isNotValidArchivalRule(MonitoringUtil.MonitoringRule monitoringRule) {
        if(monitoringRule.eventTypeInterval == null
            || !Trigger.isInsert && (monitoringRule.actions == null
            || monitoringRule.actions.isEmpty()
            || monitoringRule.filters == null
            || monitoringRule.filters.isEmpty())) {
            return true;
        }
        return false;
    }

    public static Boolean isNotValidMonitoringRule(MonitoringUtil.MonitoringRule monitoringRule) {
        if(monitoringRule.eventTypeInterval == null
            || monitoringRule.threshold == null
            || String.isBlank(monitoringRule.ruleSubType)
            || !Trigger.isInsert && (monitoringRule.actions == null
            || monitoringRule.actions.isEmpty())) {
            return true;
        }
        return false;
    }

    public static Boolean isNotValidJiraUpdateRule(MonitoringUtil.MonitoringRule monitoringRule) {
        if(!Trigger.isInsert && (monitoringRule.actions == null || monitoringRule.actions.isEmpty())) {
            return true;
        }
        return false;
    }

    public static Boolean isNotValidNotificationRule(MonitoringUtil.MonitoringRule monitoringRule) {
        if(!Trigger.isInsert && (monitoringRule.actions == null || monitoringRule.actions.isEmpty())) {
            return true;
        }
        return false;
    }

    public static List<MonitoringUtil.MonitoringRule> getRules(List<Id> ruleIds){
        String ruleFilterFields = '(SELECT Id, Index__c, ComparisonOperator__c,FieldName__c, Value__c, Comparison_Type__c, Field_Type__c FROM RuleFilters__r ORDER BY Index__c ASC NULLS LAST)';
        String ruleActionFields = '(SELECT Id, Action__r.Type__c,Action__r.Action_Type__c, Action__r.Subtype__c,Action__r.Body__c,Action__r.CreatedDate__c,Action__r.Description__c,Action__r.EmailBody__c,Action__r.EmailCC__c,Action__r.EmailTemplateId__c,Action__r.EmailTo__c,Action__r.JIRAAssignee__c,Action__r.JIRAAssignee_Id__c,Action__r.JIRAComponents__c,Action__r.JIRAEpic__c,Action__r.JIRAIssueType__c,Action__r.JIRALabels__c,Action__r.JIRAPriority__c,Action__r.JIRAProject__c,Action__r.SlackChannels__c,Action__r.Subject__c,Action__r.PagerDuty_Type__c FROM RuleActions__r)';
        Set<String> monitoringFields = new Set<String>{'Id', 'AggregateInterval__c', 'AggregateType__c', 'ComparisonOperator__c', 'Threshold__c', 'FilterLogic__c', 'EventTimeInterval__c', 'Type__c', 'Subtype__c', 'Related_Id__c', ruleFilterFields, ruleActionFields};

        String query = new QBuilder(Rule__c.SObjectType)
            .selectFields(monitoringFields)
            .add(QBuilder.condition('Active__c').equalsTo(true))
            .add(QBuilder.condition('Id').isIn(':ruleIds'))
            .build();
        List<MonitoringUtil.MonitoringRule> result = new List<MonitoringUtil.MonitoringRule>();

        for(Rule__c rule : Database.query(query)) {
            result.add(new MonitoringUtil.MonitoringRule(rule)
                .addFilters(rule.RuleFilters__r)
                .addActions(rule.RuleActions__r)
            );
        }
        return result;
    }
}