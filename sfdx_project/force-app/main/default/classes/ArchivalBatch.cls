public with sharing class ArchivalBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

	private EventAction__c eventAction;

	public ArchivalBatch(EventAction__c eventAction) {
		this.eventAction = getEventAction(eventAction.Id);
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		List<MonitoringUtil.MonitoringRule> rules = MonitoringUtil.getArchivalRules(new List<Id>{this.eventAction.Event__r.Rule__c});
		List<String> logFields = MonitoringUtil.getLogFields(rules);
		List<Event__c> events = [
			SELECT Id, CreatedDate
			FROM Event__c
			WHERE Rule__c =: this.eventAction.Event__r.Rule__c
			ORDER BY CreatedDate DESC
			LIMIT 2
		];
		DateTime currentTime = DateTime.now();
		Integer shiftMinutes = Integer.valueOf(rules.get(0).eventTypeInterval);
		DateTime ruleStartTime = currentTime.addMinutes(-shiftMinutes);
		DateTime lastProcessedDatetime = null;

		for(MonitoringUtil.MonitoringRule rule : rules) {
			Event__c event = events.size() == 2 ? events.get(1) : null;
			lastProcessedDatetime = (event != null) ? event.CreatedDate.addMinutes(-shiftMinutes) : null;
		}

		QBuilder qb = MonitoringBatch.getArchivalLogsQuery(rules.get(0), new Set<String>(logFields), lastProcessedDatetime, ruleStartTime);
		String qbQuery = qb.build();

		Database.QueryLocator queryLocator = Database.getQueryLocator(qbQuery);
		return queryLocator;
	}

	public void execute(Database.BatchableContext BC, List<sObject> scope) {
		Set<Id> logIds = getLogIdsByRuleFilters(scope);
		if(!logIds.isEmpty()) {
			String actionType = eventAction.Action_Type__c != null ? eventAction.Action_Type__c : eventAction.Type__c;
			switch on MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(actionType) {
				when REMOVAL {
					removeLogs(logIds);
				}
				when ARCHIVAL_TO_BIG_OBJECT {
					archiveToBigObject(logIds);
				}
				when EXTERNAL_ARCHIVAL {
					externalArchival(logIds);
				}
			}
		}
	}

	public Set<Id> getLogIdsByRuleFilters(List<sObject> scope) {
		Set<Id> result = new Set<Id>();
		List<Log__c> logs = (List<Log__c>)scope;

		List<MonitoringUtil.MonitoringRule> rules = MonitoringUtil.getArchivalRules(new List<Id>{this.eventAction.Event__r.Rule__c});
		for(MonitoringUtil.MonitoringRule rule : rules) {
			rule.applyArchivalRules(logs);

			if(!rule.archivalLogs.isEmpty()) {
				result.addAll(rule.archivalLogs);
			}
		}
		return result;
	}

	public void finish(Database.BatchableContext BC) {
		EventAction__c toUpdate = (EventAction__c)PermissionsUtil.newSObject(Schema.sObjectType.EventAction__c);
		PermissionsUtil.putSObjectField(toUpdate, Schema.sObjectType.EventAction__c.fields.Id, this.eventAction.Id);
		PermissionsUtil.putSObjectField(toUpdate, Schema.sObjectType.EventAction__c.fields.Executed_On__c, DateTime.now());
		PermissionsUtil.performUpdateDML(new List<Sobject>{toUpdate}, Schema.sObjectType.EventAction__c);

		List<Event__c> events = [
			SELECT Id, CreatedDate
			FROM Event__c
			WHERE Rule__c =: this.eventAction.Event__r.Rule__c
			ORDER BY CreatedDate DESC
			LIMIT 2
		];
		// delete oldest events
		if(!events.isEmpty() && events.size() == 2) {
			PermissionsUtil.performDeleteDML(new List<Id>{events.get(1).Id}, Schema.sObjectType.Event__c);
		}
		MonitoringUtil.checkStartActionsBatch(false);
	}

	public void removeLogs(Set<Id> logIds) {
		if(!PermissionsUtil.ArchivalEnabled) return;

		Database.DeleteResult[] deleteResultsInboundEmails = PermissionsUtil.performDeleteDML([SELECT Id FROM Inbound_Email__c WHERE Log__c IN :logIds], Schema.sObjectType.Inbound_Email__c);
		Database.DeleteResult[] deleteResultsLogs = PermissionsUtil.performDeleteDML(new List<Id>(logIds), Schema.sObjectType.Log__c);
	}

	public void archiveToBigObject(Set<Id> logIds) {
		if(!PermissionsUtil.ArchivalEnabled) return;

		List<Archival_Log__b> archivalLogs = new List<Archival_Log__b>();
		Map<Id, Log__c> logsWithTextAreaFields = getLogsWithTextAreaFields(logIds);
		Map<Id, Log__c> logsWithoutTextAreaFields = getLogsWithoutTextAreaFields(logIds);

		for(Id logId : logIds) {
			Archival_Log__b archivalLog = (Archival_Log__b)PermissionsUtil.newSObject(Schema.sObjectType.Archival_Log__b);
			PermissionsUtil.putSObjectField(archivalLog, Schema.sObjectType.Archival_Log__b.fields.Body__c, getLogBody(logsWithoutTextAreaFields.get(logId), logsWithTextAreaFields.get(logId)));
			PermissionsUtil.putSObjectField(archivalLog, Schema.sObjectType.Archival_Log__b.fields.Created_At__c, DateTime.now());
			PermissionsUtil.putSObjectField(archivalLog, Schema.sObjectType.Archival_Log__b.fields.Log_Id__c, logId);
			archivalLogs.add(archivalLog);
		}
		if(!Test.isRunningTest()) {
			List<Database.SaveResult> srs = PermissionsUtil.performInsertImmediateDML(archivalLogs, Schema.sObjectType.Archival_Log__b);
		}
	}

	public void externalArchival(Set<Id> logIds) {
		if(!PermissionsUtil.SplunkIntegrationEnabled) return;

		try {
			SplunkService.sendLog((new List<Id>(logIds)).get(0));
		}
		catch(Exception e) {}
	}

	public static EventAction__c getEventAction(Id eventActionId) {
		List<EventAction__c> actions = [
			SELECT Id, Executed_On__c,  Type__c, Action_Type__c,
				Action__c, Event__c, Contents__c,
				Action__r.Body__c, Action__r.Description__c, Action__r.EmailBody__c,
				Action__r.EmailCC__c, Action__r.EmailTemplateId__c, Action__r.EmailTo__c,
				Action__r.JIRAAssignee__c,Action__r.JIRAAssignee_Id__c,  Action__r.JIRAComponents__c,  Action__r.JIRAEpic__c,
				Action__r.JIRAIssueType__c,  Action__r.JIRALabels__c,  Action__r.JIRAPriority__c,
				Action__r.JIRAProject__c,  Action__r.SlackChannels__c,  Action__r.Subject__c,
				Event__r.RecordCount__c, Event__r.Criteria__c, Response__c,
				Event__r.Records__c, Event__r.Grouped_Field_Values__c,
				Event__r.Rule__r.EventTimeInterval__c, Event__r.CreatedDate,
				Action__r.PagerDuty_Type__c, Action__r.Contact__c
			FROM EventAction__c
			WHERE Id = :eventActionId
		];
		return actions.get(0);
	}

	public static String getLogBody(Log__c log, Log__c logWithTextAreaFields) {
		Map<String, Object> logMapResult = new Map<String, Object>();
		Map<String, Object> logMap = log.getPopulatedFieldsAsMap();
		Map<String, Object> logMapTE = logWithTextAreaFields.getPopulatedFieldsAsMap();
		logMapResult.putAll(logMap);
		logMapResult.putAll(logMapTE);
		return JSON.serialize(logMapResult);
	}

	public static Map<Id, Log__c> getSObjectLogs(Set<Id> logIds, Boolean excludeTextAreaFields) {
		String logName = MonitoringUtil.getPackageLogObjectName();
		List<String> logFields = getLogFields(excludeTextAreaFields);
		String queryString = 'SELECT ' + String.join(logFields, ',') + ' FROM ' + logName + ' WHERE Id IN :logIds';
		List<Log__c> logsTE = (List<Log__c>)Database.query(queryString);
		Map<Id, Log__c> logsTEMap = new Map<Id, Log__c>(logsTE);
		return logsTEMap;
	}

	public static Map<Id, Log__c> getLogsWithoutTextAreaFields(Set<Id> logIds) {
		return getSObjectLogs(logIds, true);
	}

	public static Map<Id, Log__c> getLogsWithTextAreaFields(Set<Id> logIds) {
		return getSObjectLogs(logIds, false);
	}

	public static List<String> getLogFields(Boolean excludeTextAreaFields) {
		List<String> result = new List<String>();
		Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Log__c.fields.getMap();

		for(String fieldName : fieldMap.keySet()) {
			Schema.SObjectField field = fieldMap.get(fieldName);
			Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
			switch on fieldDescribe.getType() {
				when TextArea {
					if(!excludeTextAreaFields) {
						result.add(fieldName);
					}
				}
				when else {
					if(excludeTextAreaFields) {
						result.add(fieldName);
					}
				}
			}
		}
		return result;
	}
}