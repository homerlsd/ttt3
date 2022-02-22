@IsTest
private class Test_JiraTaskController {

    @TestSetup
    static void testSetup() {
        ConfigUtil.createDefaultJiraAction();
    }

    @IsTest
    static void test1 () {

        Log__c log = new Log__c();
        insert log;

        Test.startTest();

        JiraTaskController ctrl = new JiraTaskController(new ApexPages.StandardController(log));
        ctrl.createNewJiraTask();

        Test.stopTest();

        System.assertNotEquals(null, ctrl);
    }
}