@IsTest
private class ActionTriggerHelperTest {

    @IsTest
    private static void test_one_default_action_insert_positive() {
        Action__c defaultAction = ConfigUtil.createDefaultJiraAction();

        Test.startTest();
        String errorMessage = '';

        try {
            Action__c newDefaultAction = ConfigUtil.createDefaultJiraAction();
        }
        catch(Exception e) {
            errorMessage = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, errorMessage.contains(ActionTriggerHelper.ERROR_ONLY_ONE_DEFAULT_JIRA_NOTIFICATION));

        List<Action__c> actions = [SELECT Id FROM Action__c WHERE Id != :defaultAction.Id];
        System.assertEquals(0, actions.size());
    }

    @IsTest
    private static void test_one_default_action_insert_negative() {
        Action__c defaultAction = new Action__c(Type__c = MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION, Subtype__c = null);
        insert defaultAction;

        Test.startTest();
        Action__c newDefaultAction = ConfigUtil.createDefaultJiraAction();
        Test.stopTest();

        List<Action__c> actions = [SELECT Id FROM Action__c WHERE Id = :newDefaultAction.Id];
        System.assertEquals(1, actions.size());
    }

    @IsTest
    private static void test_one_default_action_update_positive() {
        Action__c testAction = new Action__c(Type__c = MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION, Subtype__c = null);
        Action__c defaultAction = ConfigUtil.createDefaultJiraAction();
        insert new List<Action__c> {testAction};

        Test.startTest();
        String errorMessage = '';

        try {
            testAction.Subtype__c = MonitoringUtil.ACTION_SUBTYPE_DEFAULT;
            update testAction;
        }
        catch(Exception e) {
            errorMessage = e.getMessage();
        }
        System.assertEquals(true, errorMessage.contains(ActionTriggerHelper.ERROR_ONLY_ONE_DEFAULT_JIRA_NOTIFICATION));

        Test.stopTest();

        List<Action__c> actions = [SELECT Id, Subtype__c FROM Action__c WHERE Id = :testAction.Id];
        System.assertEquals(1, actions.size());
        System.assertEquals(null, actions.get(0).Subtype__c);
    }

    @IsTest
    private static void test_one_default_action_update_negative() {
        Action__c testAction = new Action__c(Type__c = MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION, Subtype__c = null);
        Action__c defaultAction = new Action__c(Type__c = MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION, Subtype__c = null);
        insert new List<Action__c> {testAction, defaultAction};

        Test.startTest();
        testAction.Subtype__c = MonitoringUtil.ACTION_SUBTYPE_DEFAULT;
        update testAction;
        Test.stopTest();

        List<Action__c> actions = [SELECT Id, Subtype__c FROM Action__c WHERE Id = :testAction.Id];
        System.assertEquals(1, actions.size());
        System.assertEquals(MonitoringUtil.ACTION_SUBTYPE_DEFAULT, actions.get(0).Subtype__c);
    }
}