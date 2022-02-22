public with sharing class ActionTriggerHelper {

	public static final String ERROR_ONLY_ONE_DEFAULT_JIRA_NOTIFICATION = 'Only one default Jira notification is allowed';

	public static void validateDefaultJiraAction(List<Action__c> actions, Map<Id, Action__c> oldActionsMap) {
		List<Action__c> defaultJiraAction = [
			SELECT Id
			FROM Action__c
			WHERE (Action_Type__c = :MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION OR Type__c = :MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION) AND Subtype__c = 'Default'
			LIMIT 1
		];

		for(Action__c action : actions) {
			Action__c oldAction = (oldActionsMap != null) ? oldActionsMap.get(action.Id) : null;

			if(!defaultJiraAction.isEmpty()
				&& oldAction == null
				&& (MonitoringUtil.ActionType.JIRA == MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(action.Type__c) || MonitoringUtil.ActionType.JIRA == MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(action.Action_Type__c))
				&& MonitoringUtil.ActionSubType.DEFAULT_ACTION == MonitoringUtil.MAP_ACTIONSUBTYPES_BY_STRINGS.get(action.Subtype__c)) {

				action.addError(ERROR_ONLY_ONE_DEFAULT_JIRA_NOTIFICATION);//asda
			}

			if(!defaultJiraAction.isEmpty()
				&& oldAction != null
				&& (action.Action_Type__c != oldAction.Action_Type__c || action.Type__c != oldAction.Type__c || action.Subtype__c != oldAction.Subtype__c)
				&& (MonitoringUtil.ActionType.JIRA == MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(action.Type__c) || MonitoringUtil.ActionType.JIRA == MonitoringUtil.MAP_ACTIONTYPES_BY_STRINGS.get(action.Action_Type__c))
				&& MonitoringUtil.ActionSubType.DEFAULT_ACTION == MonitoringUtil.MAP_ACTIONSUBTYPES_BY_STRINGS.get(action.Subtype__c)) {

				action.addError(ERROR_ONLY_ONE_DEFAULT_JIRA_NOTIFICATION);
			}
		}
	}
}