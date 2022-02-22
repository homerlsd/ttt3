public with sharing class MonitoringBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable,Database.RaisesPlatformEvents {

    public Enum BATCH_MODE {MONITORING, ARCHIVAL}

    @TestVisible
    private DateTime startTime;
    private Map<Id, MonitoringUtil.Event> eventsMap;
    private List<Id> ruleIds;
    private BATCH_MODE currentMode;

    public MonitoringBatch() {
        this.startTime = System.now();
        LogTriggerHelper.updateLastProcessedLogFlag(this.startTime);
        this.currentMode = BATCH_MODE.MONITORING;
    }

    public MonitoringBatch(BATCH_MODE batchMode) {
        this();
        this.currentMode = batchMode;
    }

    public void execute(SchedulableContext sc) {
        startMonitoringBatch(this.currentMode);
    }

    public static void startMonitoringBatch() {
        startMonitoringBatch(BATCH_MODE.MONITORING);
    }

    public static void startMonitoringBatch(BATCH_MODE batchMode) {
        List<AsyncApexJob> currentJobs = [
            SELECT Id, JobType, ApexClassID, ApexClass.Name, Status
            FROM AsyncApexJob
            WHERE Status IN ('Processing','Preparing','Queued', 'Holding')
                AND JobType != 'BatchApexWorker'
                AND JobType != 'ScheduledApex'
                AND ApexClass.Name = 'MonitoringBatch'
            LIMIT 1
        ];
        if(currentJobs.isEmpty()) {
            try {
                Database.executeBatch( new MonitoringBatch(batchMode), 1);
            }
            catch(Exception e) {}
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // check concurrency jobs
        List<AsyncApexJob> currentJobs = [
            SELECT Id, JobType, ApexClassID, ApexClass.Name, Status
            FROM AsyncApexJob
            WHERE Status IN ('Processing','Preparing','Queued', 'Holding')
                AND JobType != 'BatchApexWorker'
                AND JobType != 'ScheduledApex'
                AND ApexClass.Name = 'MonitoringBatch'
                AND Id != :bc.getJobId()
            LIMIT 1
        ];
        if(!currentJobs.isEmpty()) {
            System.abortJob(bc.getJobId());
        }

        List<String> types = (this.currentMode == BATCH_MODE.ARCHIVAL)
            ? new List<String>{MonitoringUtil.RULE_TYPE_ARCHIVAL}
            : new List<String>{MonitoringUtil.RULE_TYPE_MONITORING};
        Integer limitRules = (this.currentMode == BATCH_MODE.ARCHIVAL)
            ? PermissionsUtil.MaxArchivalRules
            : PermissionsUtil.MaxMonitoringRules;
        return Database.getQueryLocator([SELECT Id, Type__c FROM Rule__c WHERE Type__c IN :types AND Active__c = true ORDER BY Index__c LIMIT :limitRules]);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<Rule__c> scopeRules = (List<Rule__c>)scope;
        switch on MonitoringUtil.ruleTypeMap.get(scopeRules.get(0).Type__c) {
            when MONITORING {
                evaluateMonitoringRules(scopeRules);
            }
            when ARCHIVAL {
                evaluateArchivalRules(scopeRules);
            }
        }
    }

    public void evaluateArchivalRules(List<Rule__c> scopeRules) {
        if(!PermissionsUtil.ArchivalEnabled) return;

        List<MonitoringUtil.MonitoringRule> rules = MonitoringUtil.getArchivalRules(new List<Id>{scopeRules.get(0).Id});
        Map<Id, MonitoringUtil.Event> eventsMap = MonitoringUtil.getLastCreatedEventsMap();
        List<String> logFields = MonitoringUtil.getLogFieldNames(rules);

        DateTime currentTime = DateTime.now();
        Integer shiftMinutes = Integer.valueOf(rules.get(0).eventTypeInterval);
        DateTime ruleStartTime = currentTime.addMinutes(-shiftMinutes);
        DateTime lastProcessedDatetime = null;
        this.eventsMap = eventsMap;
        this.ruleIds = new List<Id>();

        for(MonitoringUtil.MonitoringRule rule : rules) {
            MonitoringUtil.Event event = eventsMap.get(rule.ruleId);
            ruleIds.add(rule.ruleId);
            lastProcessedDatetime = (event != null) ? event.CreatedDate.addMinutes(-shiftMinutes) : null;
        }

        QBuilder qb = MonitoringBatch.getArchivalLogsQuery(rules.get(0), new Set<String>(logFields), lastProcessedDatetime, ruleStartTime);
        String qbQuery = qb.build();
        List<Log__c> logs = Database.query(qbQuery);

        if(!logs.isEmpty()) {
            MonitoringUtil.evaluateArchivalRules(rules, logs);
        }
    }

    public void evaluateMonitoringRules(List<Rule__c> scopeRules) {
        if (PermissionsUtil.MonitoringEnabled && ConfigUtil.SETTINGS.Monitoring_Enabled__c) {

            List<MonitoringUtil.MonitoringRule> rules = MonitoringUtil.getMonitoringRules(new List<Id>{scopeRules.get(0).Id});
            Map<Id, MonitoringUtil.Event> eventsMap = MonitoringUtil.getLastCreatedEventsMap();

            DateTime currentTime = DateTime.now();
            DateTime lastProcessedDatetime = null;
            this.eventsMap = eventsMap;
            this.ruleIds = new List<Id>();

            for(MonitoringUtil.MonitoringRule rule : rules) {
                MonitoringUtil.Event event = eventsMap.get(rule.ruleId);
                ruleIds.add(rule.ruleId);

                if(event == null) {
                    lastProcessedDatetime = currentTime.addMinutes(-Integer.valueOf(rule.eventTypeInterval));
                }
                else {
                    if(event.createdDate != null && (rule.nextRunTime(event.createdDate) <= currentTime)) {
                        lastProcessedDatetime = event.createdDate;
                    }
                }
            }
            if(lastProcessedDatetime != null) {

                QBuilder qbCount = getMonitoringLogsQuery(rules.get(0), new Set<String>{'COUNT()'});
                String qbCountQuery = qbCount.build();
                Integer countLogs = Database.countQuery(qbCountQuery);
                Integer limitRows = (countLogs > 45000) ? 45000 : null;

                List<String> logFields = MonitoringUtil.getLogFieldNames(rules);
                QBuilder qb = getMonitoringLogsQuery(rules.get(0), new Set<String>(logFields));
                if(limitRows != null) {
                    qb.addLimit(limitRows);
                }
                String qbQuery = qb.build();
                List<Log__c> logs = Database.query(qbQuery);

                MonitoringUtil.evaluateRules(logs, this.ruleIds, this.startTime, eventsMap);
            }
        }
    }

    public static QBuilder getMonitoringLogsQuery(MonitoringUtil.MonitoringRule rule, Set<String> logFields) {
        List<MonitoringUtil.RuleFilter> queryableFilters = rule.getQueryableFilters();
        QBuilder qb = getLogsQuery(rule, logFields, queryableFilters)
            .add(QBuilder.condition('Created_At__c').isGreaterOrEquals(':lastProcessedDatetime'))
            .add(!PermissionsUtil.NotificationForPharosErrors ? QBuilder.condition('Category__c').notEqualsTo(Logger.CATEGORY_PHAROS_ERROR) : null)
            .add(!PermissionsUtil.NotificationForPharosErrors ? QBuilder.condition('Area__c').notEqualsTo(Logger.AREA_PHAROS_ERROR) : null);

        if(!queryableFilters.isEmpty()) {
            String basicFilters = !PermissionsUtil.NotificationForPharosErrors ? (' AND (' + (queryableFilters.size() + 1) + ' AND ' + (queryableFilters.size() + 2) + ' AND ' + (queryableFilters.size() + 3) + ')')
                : ' AND (' + (queryableFilters.size() + 1) + ')';
            if(String.isNotBlank(rule.filterLogic)) {
                String conditionOrder = '(' + rule.filterLogic + ')' + basicFilters;
                qb.setConditionOrder(conditionOrder);
            }
        }
        return qb;
    }


    public static QBuilder getArchivalLogsQuery(MonitoringUtil.MonitoringRule rule, Set<String> logFields, DateTime lastProcessedDatetime, DateTime ruleStartTime) {
        List<MonitoringUtil.RuleFilter> queryableFilters = rule.getQueryableFilters();
        QBuilder qb = getLogsQuery(rule, logFields, queryableFilters)
            .add(lastProcessedDatetime != null ? QBuilder.condition('Created_At__c').isGreaterThan(':lastProcessedDatetime') : null)
            .add(QBuilder.condition('Created_At__c').isLessThan(':ruleStartTime'));
        return qb;
    }

    public static QBuilder getLogsQuery(MonitoringUtil.MonitoringRule rule, Set<String> logFields, List<MonitoringUtil.RuleFilter> queryableFilters) {
        QBuilder qb = new QBuilder(Log__c.SObjectType)
            .selectFields(new Set<String>(logFields));

        if(!queryableFilters.isEmpty()) {
            for(MonitoringUtil.RuleFilter rf : queryableFilters) {
                QCondition condition = new QCondition(rf.fieldName);
                Object fieldValue = rf.value;
                switch on rf.fieldType {
                    when FT_DOUBLE, FT_NUMBER {
                        fieldValue = Decimal.valueOf(rf.value);
                    }
                    when FT_DATE {
                        fieldValue = Date.valueOf(rf.value);
                    }
                    when FT_DATETIME {
                        fieldValue = DateTime.valueOf(rf.value);
                    }
                    when FT_BOOLEAN {
                        fieldValue = Boolean.valueOf(rf.value);
                    }
                }
                condition.setOperatorValue(
                    filterToConditionMap.get(rf.comparisonOperatorType),
                    fieldValue
                );
                qb.add(condition);
            }
        }

        return qb;
    }

    private static Map<MonitoringUtil.ComparisonOperator, QCondition.ComparisonOperator> filterToConditionMap = new Map<MonitoringUtil.ComparisonOperator, QCondition.ComparisonOperator>{
        MonitoringUtil.ComparisonOperator.EQUAL => QCondition.ComparisonOperator.EQUALS,
        MonitoringUtil.ComparisonOperator.NOT_EQUAL => QCondition.ComparisonOperator.NOT_EQUALS,
        MonitoringUtil.ComparisonOperator.GREATER_THAN => QCondition.ComparisonOperator.GREATER_THAN,
        MonitoringUtil.ComparisonOperator.GREATER_OR_EQUAL => QCondition.ComparisonOperator.GREATER_OR_EQUAL,
        MonitoringUtil.ComparisonOperator.LESS_THAN => QCondition.ComparisonOperator.LESS_THAN,
        MonitoringUtil.ComparisonOperator.LESS_OR_EQUAL => QCondition.ComparisonOperator.LESS_OR_EQUAL
    };

    public void finish(Database.BatchableContext BC) {
        if(hasNewLogs() && LogTriggerHelper.needRunMonitoringRules()) {
            MonitoringBatch.startMonitoringBatch();
        }
        else {
            MonitoringUtil.checkStartActionsBatch(false);
        }
    }

    public static Boolean hasNewLogs() {
        Monitoring_Batch_Flag__c flag = Monitoring_Batch_Flag__c.getOrgDefaults();
        Boolean hasNewLogs = false;
        if(flag.Last_Created_Log__c != null && flag.Last_Processed_Log__c != null) {
            hasNewLogs = flag.Last_Created_Log__c > flag.Last_Processed_Log__c;
        }
        return hasNewLogs;
    }
}