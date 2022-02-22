@IsTest
private class BroadcastServiceTest {

    @TestSetup
    private static void testSetup() {
        TestDataFactory.createConnectedOrg();
    }

    @IsTest
    private static void test_send_to() {
        Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15));
        corg.Data_Direction__c = 'sendTo';
        update corg;
        Test.startTest();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Instance_Url' + ConfigUtil.PHAROS_REST_SERVICE_ENDPOINT + '?' + ConfigUtil.PARAMS_TYPE + '=' + ConfigUtil.TYPE_BROADCAST, sendLogMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        BroadcastService.sendLog(new Log__c());
        Test.stopTest();
    }

    @IsTest
    private static void test_parse_incoming_data_logs() {
        Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15));
        corg.Data_Direction__c = 'receiveFrom';
        update corg;
        Test.startTest();
        BroadcastService.IncomingData incomingData = new BroadcastService.IncomingData();
        incomingData.logs = new List<Log__c>{new Log__c()};
        Map<String, String> mapRecordTypesById = new Map<String, String>();
        for (String id : Schema.SObjectType.Log__c.getRecordTypeInfosById().keySet()) {
            mapRecordTypesById.put(id, Schema.SObjectType.Log__c.getRecordTypeInfosById().get(id).getName());
        }
        incomingData.mapRecordTypesById = mapRecordTypesById;
        incomingData.organizationId = UserInfo.getOrganizationId().left(15);
        BroadcastService.parseIncomingData(incomingData);
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM Log__c].size());
    }

    @IsTest
    private static void test_parse_incoming_data_content_version() {
        Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15));
        corg.Data_Direction__c = 'receiveFrom';
        update corg;
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S';
        contentVersion.Title = 'test_title';
        contentVersion.PathOnClient = 'test_path';
        BroadcastService.IncomingData incomingData = new BroadcastService.IncomingData();
        incomingData.contentVersionWrapper = new BulkAPIJobBatchService.ContentVersionWrapper(contentVersion, 'test');
        incomingData.organizationId = UserInfo.getOrganizationId().left(15);
        BroadcastService.parseIncomingData(incomingData);
        System.assertEquals(1, [SELECT Id FROM ContentVersion].size());
    }

    private static TestDataFactory.SingleRequestMock sendLogMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                'Done'
        );
        return singleRequestMock;
    }

}