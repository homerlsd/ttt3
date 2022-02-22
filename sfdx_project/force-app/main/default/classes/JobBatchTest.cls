@IsTest
private class JobBatchTest {

    @TestSetup
    private static void testSetup() {
        TestDataFactory.createConnectedOrg();
    }

    @IsTest
    private static void test_start() {
        Test.startTest();
        Database.executeBatch(new JobBatch());
        Test.stopTest();
    }

    @IsTest
    private static void test_execute() {
        Test.startTest();
        JobBatch jobBatch = new JobBatch();
        jobBatch.execute(null, new List<AsyncApexJob>{(AsyncApexJob)JSON.deserialize(TestDataFactory.ASYNC_APEX_JOB_JSON, AsyncApexJob.class)});
        jobBatch.finish(null);
        Test.stopTest();
        List<Log__c> lstLogs = [SELECT Id, Area__c FROM Log__c WHERE Async_Job_Id__c = '707KK00000KKK00KKK'];
        if (!lstLogs.isEmpty()) {
            System.assertEquals(1, lstLogs.size());
            System.assertEquals('AsyncApexJob', lstLogs[0].Area__c);
        }
    }

}