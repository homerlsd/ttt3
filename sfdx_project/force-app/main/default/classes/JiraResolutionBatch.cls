public with sharing class JiraResolutionBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable,Database.RaisesPlatformEvents {

	public JiraResolutionBatch(){}

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new JiraResolutionBatch(), 100);
	}

	public Database.QueryLocator start(Database.BatchableContext BC){
		JiraService.validateAndRefreshJiraOauthToken();
		
		return Database.getQueryLocator([
			SELECT Id, Bug_Tracker__c, Resolved_On__c
			FROM Log__c
			WHERE Bug_Tracker__c != NULL AND Resolved_On__c = NULL
			ORDER BY Created_At__c
		]);
	}

	public void execute(Database.BatchableContext BC, List<SObject> scope){
		List<Log__c> logs = (List<Log__c>)scope;
		List<Log__c> toUpdate = new List<Log__c>();

		if(!logs.isEmpty() && String.isNotBlank(ConfigUtil.JIRA_OAUTH_TOKEN)) {

			List<String> keys = JiraService.getJiraKeys(logs);
			Map<String, DateTime> resolutionDatetimes = JiraService.getResolutionDatetimeByTaskKey(keys);

			for(Log__c log : logs) {
				String key = JiraService.getLogJiraKey(log);
				if(String.isNotBlank(key)) {
					DateTime resolutionDatetime = resolutionDatetimes.get(key);
					if(resolutionDatetime != null) {
						toUpdate.add(new Log__c(Id = log.Id, Resolved_On__c = resolutionDatetime));
					}
				}
			}
			if(!toUpdate.isEmpty()) {
				update toUpdate;
			}
		}
	}

	public void finish(Database.BatchableContext BC){}
}