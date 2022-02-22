@IsTest
private class AdminServiceTest {

    @IsTest
    static void test_getUserInfo() {
        User result;
        Test.startTest();
        result = AdminService.getUserInfo();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.FirstName);
        System.assertNotEquals(null, result.LastName);
        System.assertNotEquals(null, result.Email);
        System.assertNotEquals(null, result.CompanyName);
    }

    @IsTest
    static void test_isMyDomainEnabled() {
        Map<String, Boolean> result;
        Test.startTest();
        result = AdminService.isMyDomainEnabled();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey('enabled'));
    }

    @IsTest
    static void test_getMergeFields() {
        List<AdminService.MergeField> result;
        Test.startTest();
        result = (List<AdminService.MergeField>)AdminService.getMergeFields();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty());
    }

    @IsTest
    static void test_getAppPermissions() {
        Map<String, Object> result;
        Test.startTest();
        result = (Map<String, Object>)AdminService.getAppPermissions((Object)null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty());
    }

    @IsTest
    static void test_getRemoteSiteSettings() {
        List<AdminService.RemoteSiteSettingsWrapper> result;
        mockRemoteSiteSetting(TestDataFactory.getRemoteSiteSettings());
        Test.startTest();
        result = AdminService.getRemoteSiteSettings();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty());
    }

    static void mockRemoteSiteSetting(List<AdminService.RemoteSiteSettingsWrapper> records) {
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        Map<String, Object> data = new Map<String, Object>{
            ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS => records
        };
        TestDataFactory.SingleRequestMock remoteSiteSettingsMock = new TestDataFactory.SingleRequestMock(
            200,
            'OK',
            JSON.serialize(data)
        );
        endpoint2TestResp.put(ConfigUtil.TOOLING_QUERY_ENDPOINT + ConfigUtil.REST_REMOTE_SITE_SETTINGS_QUERY, remoteSiteSettingsMock);
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
    }

    @IsTest
    static void test_getConnectedOrgsInfo() {
        Map<String, Object> result;
        TestDataFactory.createConnectedOrg();
        Test.startTest();
        result = (Map<String, Object>)AdminService.getConnectedOrgsInfo();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty());
        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTED_ORGS_INFO_KEY_CONNECTED_ORGS));
    }

    @IsTest
    static void test_getSelfConnectedOrgsInfo() {
        Map<String, Object> result;
        TestDataFactory.createConnectedOrg();
        Test.startTest();
        result = (Map<String, Object>)AdminService.getSelfConnectedOrgsInfo();
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.isEmpty());
        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTED_ORGS_INFO_KEY_CONNECTED_ORGS));
    }

    @IsTest
    static void test_updatePassthroughtMode() {
        AdminService.ConnectedOrgsSettings result;
        AdminService.ConnectedOrgsSettings wrapper = new AdminService.ConnectedOrgsSettings();
        wrapper.passthroughtMode = true;

        Test.startTest();
        result = (AdminService.ConnectedOrgsSettings)AdminService.updatePassthroughtMode(wrapper);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.passthroughtMode);
    }

    @IsTest
    static void test_createConnectionOrg() {
        Map<String, Object> result;
        AdminService.ConnectedOrgCreateData wrapper = new AdminService.ConnectedOrgCreateData();
        wrapper.name = 'test1';
        wrapper.description = 'test2';
        wrapper.type = 'production';
        TestDataFactory.createConnectedOrgSettings();
        mockPlatformEventSubscriberConfig();

        Test.startTest();
        result = (Map<String, Object>)AdminService.createConnectionOrg(wrapper);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTION_ORG_KEY_CORG));
        AdminService.ConnectedOrgDTO createData = (AdminService.ConnectedOrgDTO)result.get(ConfigUtil.CONNECTION_ORG_KEY_CORG);
        System.assertNotEquals(null, createData);
        System.assertEquals(wrapper.name, createData.name);
        System.assertEquals(wrapper.description, createData.description);
        System.assertEquals(wrapper.type, createData.type);

        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTION_ORG_KEY_CLIENT_KEY));
    }

    static void mockPlatformEventSubscriberConfig() {

        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(apexPlatformEventTriggerMockEndpoint(), apexPlatformEventTriggerMock());
        endpoint2TestResp.put(platformEventSubscriberConfigMockEndpoint(), platformEventSubscriberConfigMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
    }

    static String platformEventSubscriberConfigMockEndpoint() {
        String query = new QBuilder('PlatformEventSubscriberConfig')
            .selectFields(new Set<String>{'Id','UserId', 'PlatformEventConsumerId', 'DeveloperName', 'MasterLabel','BatchSize'})
            .add(QBuilder.condition('DeveloperName').equalsTo(AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME))
            .add(QBuilder.condition('NamespacePrefix').equalsTo(ConfigUtil.currentOrgNameSpacePrefix))
            .addLimit(1)
            .build();
        return System.Url.getOrgDomainUrl().toExternalForm() + ConfigUtil.TOOLING_QUERY_API_51_ENDPOINT + EncodingUtil.urlEncode(query, 'UTF-8');
    }

    static String apexPlatformEventTriggerMockEndpoint() {
        String query = new QBuilder(ApexTrigger.SObjectType)
            .selectFields(new Set<String>{'Id'})
            .add(QBuilder.condition('Name').equalsTo(AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_TRIGGER_NAME))
            .add(QBuilder.condition('NamespacePrefix').equalsTo(ConfigUtil.getNameSpace()))
            .addLimit(1)
            .build();

        return System.Url.getOrgDomainUrl().toExternalForm() + ConfigUtil.TOOLING_QUERY_PATH + EncodingUtil.urlEncode(query, 'UTF-8');
    }

    static TestDataFactory.SingleRequestMock apexPlatformEventTriggerMock() {
        Id platformEventApexTriggerId = [SELECT Id FROM ApexTrigger WHERE Name =: AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_TRIGGER_NAME LIMIT 1].Id;

        Map<String, Object> data = new Map<String, Object>{
            ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS => new List<ApexTrigger>{new ApexTrigger(Id = platformEventApexTriggerId)}
        };
        TestDataFactory.SingleRequestMock apexPlatformEventTriggerMock = new TestDataFactory.SingleRequestMock(
            200,
            'OK',
            JSON.serialize(data)
        );
        return apexPlatformEventTriggerMock;
    }

    static TestDataFactory.SingleRequestMock platformEventSubscriberConfigMock() {
        AdminService.PlatformEventSubscriberConfigWrapper wrapper = new AdminService.PlatformEventSubscriberConfigWrapper();
        wrapper.UserId = UserInfo.getUserId();
        wrapper.PlatformEventConsumerId = [SELECT Id FROM ApexTrigger WHERE Name =: AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_TRIGGER_NAME LIMIT 1].Id;
        wrapper.MasterLabel = AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME;
        wrapper.DeveloperName = AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME;
        wrapper.BatchSize = AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_BATCH_SIZE;
        Map<String, Object> data = new Map<String, Object>{
            ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS => new List<AdminService.PlatformEventSubscriberConfigWrapper>{wrapper}
        };
        TestDataFactory.SingleRequestMock platformEventSubscriberConfigMock = new TestDataFactory.SingleRequestMock(
            200,
            'OK',
            JSON.serialize(data)
        );
        return platformEventSubscriberConfigMock;
    }


    @IsTest
    static void test_createSelfConnectionOrg() {
        Map<String, Object> result;
        AdminService.ConnectedOrgCreateData wrapper = new AdminService.ConnectedOrgCreateData();
        wrapper.name = UserInfo.getOrganizationName();
        wrapper.description = UserInfo.getOrganizationName();
        TestDataFactory.createConnectedOrgSettings();
        mockPlatformEventSubscriberConfig();

        Test.startTest();
        result = (Map<String, Object>)AdminService.createSelfConnectionOrg(wrapper);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTION_ORG_KEY_CORG));
        AdminService.ConnectedOrgDTO createData = (AdminService.ConnectedOrgDTO)result.get(ConfigUtil.CONNECTION_ORG_KEY_CORG);
        System.assertNotEquals(null, createData);
        System.assertEquals(wrapper.name, createData.name);
        System.assertEquals(wrapper.description, createData.description);
        System.assertNotEquals(null, createData.instanceUrl);
        System.assertNotEquals(null, createData.type);
    }

    @IsTest
    static void test_updateConnectedOrg() {
        Map<String, Object> result;
        TestDataFactory.createConnectedOrgSettings();
        TestDataFactory.createConnectedOrg();
        AdminService.ConnectedOrgDTO wrapper = new AdminService.ConnectedOrgDTO(ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15)));
        wrapper.name = 'test1';
        wrapper.description = 'test2';

        Test.startTest();
        result = (Map<String, Object>)AdminService.updateConnectedOrg(wrapper);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTION_ORG_KEY_CORG));
        AdminService.ConnectedOrgDTO createData = (AdminService.ConnectedOrgDTO)result.get(ConfigUtil.CONNECTION_ORG_KEY_CORG);
        System.assertNotEquals(null, createData);
        System.assertEquals(wrapper.name, createData.name);
        System.assertEquals(wrapper.description, createData.description);

        System.assertEquals(true, result.containsKey(ConfigUtil.CONNECTION_ORG_KEY_CLIENT_KEY));
    }

    @IsTest
    static void test_refreshConnectedOrgToken() {
        AdminService.ConnectedOrgDTO result;
        TestDataFactory.createConnectedOrgSettings();
        TestDataFactory.createConnectedOrg();
        AdminService.ConnectedOrgDTO wrapper = new AdminService.ConnectedOrgDTO(ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15)));
        mockRefreshToken();
        Test.startTest();
        result = (AdminService.ConnectedOrgDTO)AdminService.refreshConnectedOrgToken(wrapper);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    static void mockRefreshToken() {
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Instance_Url/services/oauth2/token', refreshTokenMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
    }

    static TestDataFactory.SingleRequestMock refreshTokenMock() {
        ConnectedOrgService.AuthTokenResponse authTokenResponse = new ConnectedOrgService.AuthTokenResponse();
        authTokenResponse.access_token = 'test_new_Access_Token';
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
            200,
            'OK',
            JSON.serialize(authTokenResponse)
        );
        return singleRequestMock;
    }

    @IsTest
    static void test_testConnectedOrg() {
        String result;
        TestDataFactory.createConnectedOrgSettings();
        TestDataFactory.createConnectedOrg();
        AdminService.ConnectedOrgDTO wrapper = new AdminService.ConnectedOrgDTO(ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15)));
        mockGetIdentity();
        Test.startTest();
        result = (String)AdminService.testConnectedOrg(wrapper);
        Test.stopTest();
        System.assertEquals(ConfigUtil.CONNECTED_ORG_TESTING_KEY_SUCCESS, result);
    }

    static void mockGetIdentity() {
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Identity_Url', getIdentityMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
    }

    static TestDataFactory.SingleRequestMock getIdentityMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
            200,
            'OK',
            '{}'
        );
        return singleRequestMock;
    }

    @IsTest
    static void test_deleteFakeConnectedOrg() {
        TestDataFactory.createConnectedOrgSettings();
        Connected_Org__c fakeConnectedOrg = ConnectedOrgService.createConnectedOrg('fake', 'production', 'description', '');

        Test.startTest();
        AdminService.deleteFakeConnectedOrg();
        Test.stopTest();

        Connected_Org__c fakeConnectedOrgAfterDelte = ConnectedOrgService.getConnectedOrgById(fakeConnectedOrg.Name);
        System.assertEquals(null, fakeConnectedOrgAfterDelte);
    }


    @IsTest
    static void test_deleteConnectedOrg() {
        Boolean result;
        TestDataFactory.createConnectedOrgSettings();
        TestDataFactory.createConnectedOrg();
        AdminService.ConnectedOrgDTO wrapper = new AdminService.ConnectedOrgDTO(ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId().left(15)));
        mockGetIdentity();
        Test.startTest();
        result = (Boolean)AdminService.deleteConnectedOrg(wrapper);
        Test.stopTest();
        System.assertEquals(true, result);
        Connected_Org__c connectedOrgAfterDelte = ConnectedOrgService.getConnectedOrgById(wrapper.orgId);
        System.assertEquals(null, connectedOrgAfterDelte);
    }

    @IsTest
    static void test_setupRemoteSiteSettings() {
        String result;
        mockRemoteSiteSetting(TestDataFactory.getDefaultRemoteSiteSettings());
        Test.startTest();
        result = (String)AdminService.setupRemoteSiteSettings();
        Test.stopTest();
        System.assertEquals('success', result);
    }

    @IsTest
    static void test_getEmailServiceData() {
        Map<String, Object> result;
        mockGetEmailServiceDataRequests();

        Test.startTest();
        result = (Map<String, Object>)AdminService.getEmailServiceData();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    static void mockGetEmailServiceDataRequests() {
        System.Test.setMock(WebServiceMock.class, new GetEmailServiceDataWebServiceMockImpl());
    }

    public class GetEmailServiceDataWebServiceMockImpl implements WebServiceMock {

        public void doInvoke(
                Object stub,
                Object request,
                Map<String, Object> response,
                String endpoint,
                String soapAction,
                String requestName,
                String responseNS,
                String responseName,
                String responseType) {

            if(requestName == 'readMetadata' && responseType == 'MetadataService.readFlowSettingsResponse_element') {
                MetadataService.readFlowSettingsResponse_element metadataResponse = new MetadataService.readFlowSettingsResponse_element();
                MetadataService.ReadFlowSettingsResult result = new MetadataService.ReadFlowSettingsResult();
                result.records = new List<MetadataService.FlowSettings>();
                MetadataService.FlowSettings flowSettings = new MetadataService.FlowSettings();
                flowSettings.enableFlowUseApexExceptionEmail = true;
                result.records.add(flowSettings);
                metadataResponse.result = result;
                response.put('response_x', metadataResponse);
            }
            if(requestName == 'readMetadata' && responseType == 'MetadataService.readCaseSettingsResponse_element') {
                MetadataService.readCaseSettingsResponse_element metadataResponse = new MetadataService.readCaseSettingsResponse_element();
                MetadataService.ReadCaseSettingsResult result = new MetadataService.ReadCaseSettingsResult();
                result.records = new List<MetadataService.CaseSettings>();
                MetadataService.CaseSettings caseSettings = new MetadataService.CaseSettings();
                caseSettings.emailToCase = new MetadataService.EmailToCaseSettings();
                caseSettings.emailToCase.enableEmailToCase = true;
                caseSettings.defaultCaseUser = UserInfo.getUserEmail();
                result.records.add(caseSettings);
                metadataResponse.result = result;
                response.put('response_x', metadataResponse);
            }
        }
    }

}