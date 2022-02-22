@IsTest
private class BulkAPIJobBatchTest {

    @TestSetup
    private static void testSetup() {
        TestDataFactory.createConnectedOrg();
    }

    @IsTest
    private static void test_bulk_api_v1_xml() {
        Test.startTest();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest', getAllJobsMock('XML', 'Classic'));
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest/testJobId', getJobsMock('XML', 'Classic'));
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch', getBatchesXMLMock());
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch/testBatchId/result', getBatchResultXMLMock());
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch/testBatchId/request', getBatchRequestXMLMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        BulkAPIJobBatchScheduler bulkAPIJobBatchScheduler = new BulkAPIJobBatchScheduler();
        bulkAPIJobBatchScheduler.execute(null);
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM Log__c].size());
        System.assertEquals(1, [SELECT Id FROM ContentVersion].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocument].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Log__c)].size());
    }

    @IsTest
    private static void test_bulk_api_v1_json() {
        Test.startTest();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest', getAllJobsMock('JSON', 'Classic'));
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest/testJobId', getJobsMock('JSON', 'Classic'));
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch', getBatchesJSONMock());
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch/testBatchId/result', getBatchResultJSONMock());
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch/testBatchId/request', getBatchRequestJSONMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        BulkAPIJobBatchScheduler bulkAPIJobBatchScheduler = new BulkAPIJobBatchScheduler();
        bulkAPIJobBatchScheduler.execute(null);
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM Log__c].size());
        System.assertEquals(1, [SELECT Id FROM ContentVersion].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocument].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Log__c)].size());
    }

    @IsTest
    private static void test_bulk_api_v1_csv() {
        Test.startTest();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest', getAllJobsMock('CSV', 'Classic'));
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest/testJobId', getJobsMock('CSV', 'Classic'));
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch', getBatchesXMLMock());
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch/testBatchId/result', getBatchResultCSVMock());
        endpoint2TestResp.put('https://test_Instance_Url/services/async/52.0/job/testJobId/batch/testBatchId/request', getBatchRequestCSVMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        BulkAPIJobBatchScheduler bulkAPIJobBatchScheduler = new BulkAPIJobBatchScheduler();
        bulkAPIJobBatchScheduler.execute(null);
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM Log__c].size());
        System.assertEquals(1, [SELECT Id FROM ContentVersion].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocument].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Log__c)].size());
    }

    @IsTest
    private static void test_bulk_api_v2_csv() {
        Test.startTest();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest', getAllJobsMock('CSV', 'V2Ingest'));
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest/testJobId', getJobsMock('CSV', 'V2Ingest'));
        endpoint2TestResp.put('https://test_Instance_Url/services/data/v52.0/jobs/ingest/testJobId/failedResults', getJobFailedRecordResultsCSVMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        BulkAPIJobBatchScheduler bulkAPIJobBatchScheduler = new BulkAPIJobBatchScheduler();
        bulkAPIJobBatchScheduler.execute(null);
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM Log__c].size());
        System.assertEquals(1, [SELECT Id FROM ContentVersion].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocument].size());
        System.assertEquals(1, [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Log__c)].size());
    }

    private static TestDataFactory.SingleRequestMock getAllJobsMock(String contentType, String jobType) {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '{' +
                        '"done":true,' +
                        '"records":' +
                        '[' +
                        '{' +
                        '"id":"testJobId",' +
                        '"operation":"insert",' +
                        '"object":"Lead",' +
                        '"state":"Closed",' +
                        '"contentType":"' + contentType + '",' +
                        '"apiVersion":52.0,' +
                        '"jobType":"' + jobType + '"' +
                        '}' +
                        '],' +
                        '"nextRecordsUrl":null' +
                        '}'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getJobsMock(String contentType, String jobType) {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '{' +
                        '"id":"testJobId",' +
                        '"operation":"insert",' +
                        '"object":"Lead",' +
                        '"state":"Closed",' +
                        '"contentType":"' + contentType + '",' +
                        '"apiVersion":52.0,' +
                        '"jobType":"' + jobType + '",' +
                        '"numberRecordsProcessed":1,' +
                        '"numberRecordsFailed":1' +
                        '}'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchesXMLMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '<?xml version="1.0" encoding="UTF-8"?>' +
                        '<batchInfoList xmlns="http://www.force.com/2009/06/asyncapi/dataload">' +
                        '<batchInfo>' +
                        '<id>testBatchId</id>' +
                        '<jobId>testJobId</jobId>' +
                        '<state>Completed</state>' +
                        '<numberRecordsProcessed>1</numberRecordsProcessed>' +
                        '<numberRecordsFailed>1</numberRecordsFailed>' +
                        '</batchInfo>' +
                        '</batchInfoList>'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchResultXMLMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '<?xml version="1.0" encoding="UTF-8"?>' +
                        '<results xmlns="http://www.force.com/2009/06/asyncapi/dataload">' +
                        '<result>' +
                        '<errors>' +
                        '<message>Industry cannot be blank!</message>' +
                        '<statusCode>FIELD_CUSTOM_VALIDATION_EXCEPTION</statusCode>' +
                        '</errors>' +
                        '<success>false</success>' +
                        '<created>false</created>' +
                        '</result>' +
                        '</results>'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchRequestXMLMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '<?xml version="1.0" encoding="UTF-8"?>' +
                        '<sObjects xmlns="http://www.force.com/2009/06/asyncapi/dataload" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
                        '<sObject>' +
                        '<Status>New</Status>' +
                        '<Industry></Industry>' +
                        '<Company>Test Inc.</Company>' +
                        '<LastName>TestLastName</LastName>' +
                        '<Description>TestDescription</Description>' +
                        '</sObject>' +
                        '</sObjects>'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchesJSONMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '{' +
                        '"batchInfo":' +
                        '[{' +
                        '"id":"testBatchId",' +
                        '"jobId":"testJobId",' +
                        '"numberRecordsFailed":1,' +
                        '"numberRecordsProcessed":1,' +
                        '"state":"Completed"' +
                        '}]' +
                        '}'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchResultJSONMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '[' +
                        '{' +
                        '"success":false,' +
                        '"created":false,' +
                        '"id":null,' +
                        '"errors":' +
                        '[{' +
                        '"statusCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION",' +
                        '"message":"Industry cannot be blank!",' +
                        '"fields":[]' +
                        '}]' +
                        '}' +
                        ']'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchRequestJSONMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '[' +
                        '{' +
                        '"Status":"New",' +
                        '"Industry":"",' +
                        '"Company":"BigLife Inc.",' +
                        '"LastName":"TestLastName",' +
                        '"Description":"TestDescription"' +
                        '}' +
                        ']'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchResultCSVMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '"Id","Success","Created","Error"\n' +
                        '"","false","false","FIELD_CUSTOM_VALIDATION_EXCEPTION:Industry cannot be blank!:--"'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getBatchRequestCSVMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '"Company","Industry","LastName","Status","Description"\n' +
                        '"Test, Inc.",,"TestLastName","New","TestDescription"'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock getJobFailedRecordResultsCSVMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '"sf__Id","sf__Error","Company","Industry","LastName","Status","Description"\n' +
                        '"","FIELD_CUSTOM_VALIDATION_EXCEPTION:Industry cannot be blank!:--","Test, Inc.",,"TestLastName","New","TestDescription"'
        );
        return singleRequestMock;
    }

}