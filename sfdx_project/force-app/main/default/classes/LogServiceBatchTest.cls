@IsTest
private class LogServiceBatchTest {

    @TestSetup
    private static void testSetup() {
        TestDataFactory.createConnectedOrgSettings();
        TestDataFactory.createConnectedOrg();
    }

    @IsTest
    public static void test_metrics_batch_feature_parameter2() {
        Integer metrics2 = FeatureManagement.checkPackageIntegerValue(PermissionsUtil.FEATURE_PARAM_MAP_6_NAME);
        Test.startTest();

        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put(getPlatformEventConfigMockURL(), getPlatformEventConfigMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);

        List<MetadataService.CaseSettings> records = new List<MetadataService.CaseSettings>();
        MetadataService.CaseSettings settings = new MetadataService.CaseSettings();
        settings.emailToCase = new MetadataService.EmailToCaseSettings();
        settings.emailToCase.enableEmailToCase = false;
        Test.setMock(WebServiceMock.class, new YourWebServiceMockImpl(records));

        MetricsBatch.calculateOrgMetrics2();
        Test.stopTest();
        Integer metrics2After = FeatureManagement.checkPackageIntegerValue(PermissionsUtil.FEATURE_PARAM_MAP_6_NAME);
        System.assertNotEquals(metrics2, metrics2After);
    }

    @IsTest
    public static void test_metrics_batch_feature_parameter1() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            TestDataFactory.createTestNotificationLog();
        }
        Integer metrics1 = FeatureManagement.checkPackageIntegerValue(PermissionsUtil.FEATURE_PARAM_MAP_5_NAME);

        Test.startTest();
        MetricsBatch.calculateOrgMetrics();
        Test.stopTest();
        Integer metrics1After = FeatureManagement.checkPackageIntegerValue(PermissionsUtil.FEATURE_PARAM_MAP_5_NAME);
        System.assertNotEquals(metrics1, metrics1After);
    }

    @IsTest
    public static void test_scheduler() {
        Test.startTest();
        Datetime dt = Datetime.now().addSeconds(30);
        String cronExp = dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
        String jobId = System.schedule('testLogServiceScheduler', cronExp, new LogServiceScheduler());
        CronTrigger cronTrigger = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, cronTrigger.CronExpression);
        System.assertEquals(0, cronTrigger.TimesTriggered);
        System.assertEquals(dt, cronTrigger.NextFireTime);
        Test.stopTest();
    }

    @IsTest
    public static void test_batch_positive() {
        test_batch(true);
    }

    @IsTest
    public static void test_batch_negative() {
        test_batch(false);
    }

    private static void test_batch(Boolean isPositive) {
        Test.startTest();
        updateConnectedOrg();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Identity_Url', isPositive ? getIdentityMock() : invalidGrantMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        Database.executeBatch(new LogServiceBatch(), 1);
        Test.stopTest();
        List<Connected_Org__c> lstConnectedOrgs = [SELECT Id, Access_Token__c FROM Connected_Org__c LIMIT 1];
        if (!lstConnectedOrgs.isEmpty()) {
            System.assertEquals('test_Access_Token', lstConnectedOrgs[0].Access_Token__c);
        }
    }

    @IsTest
    public static void test_batch_refresh_token_positive() {
        test_batch_refresh_token(true);
    }

    @IsTest
    public static void test_batch_refresh_token_negative() {
        test_batch_refresh_token(false);
    }

    private static void test_batch_refresh_token(Boolean isPositive) {
        Test.startTest();
        updateConnectedOrg();
        Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
        endpoint2TestResp.put('https://test_Identity_Url', badOAuthTokenMock());
        endpoint2TestResp.put('https://test_Instance_Url' + ConfigUtil.SF_OAUTH_TOKEN_ENDPOINT, isPositive ? refreshTokenMock() : invalidGrantMock());
        HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
        Test.setMock(HttpCalloutMock.class, multiCalloutMock);
        Database.executeBatch(new LogServiceBatch(), 1);
        Test.stopTest();
        List<Connected_Org__c> lstConnectedOrgs = [SELECT Id, Access_Token__c FROM Connected_Org__c LIMIT 1];
        if (!lstConnectedOrgs.isEmpty()) {
            if (isPositive) {
                System.assertEquals('test_new_Access_Token', lstConnectedOrgs[0].Access_Token__c);
            } else {
                System.assertEquals('test_Access_Token', lstConnectedOrgs[0].Access_Token__c);
            }
        }
    }

    private static void updateConnectedOrg() {
        List<Connected_Org__c> lstConnectedOrgs = [SELECT Id, Scheduler_Enabled__c FROM Connected_Org__c LIMIT 1];
        if (!lstConnectedOrgs.isEmpty()) {
            lstConnectedOrgs[0].Scheduler_Enabled__c = true;
            update lstConnectedOrgs;
        }
    }

    private static TestDataFactory.SingleRequestMock getIdentityMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                '{}'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock refreshTokenMock() {
        ConnectedOrgService.AuthTokenResponse authTokenResponse = new ConnectedOrgService.AuthTokenResponse();
        authTokenResponse.access_token = 'test_new_Access_Token';
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                200,
                'OK',
                JSON.serialize(authTokenResponse)
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock badOAuthTokenMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                403,
                'Forbidden',
                'Bad_OAuth_Token'
        );
        return singleRequestMock;
    }

    private static TestDataFactory.SingleRequestMock invalidGrantMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
                400,
                'Bad Request',
                'invalid_grant'
        );
        return singleRequestMock;
    }

    private static String getPlatformEventConfigMockURL() {
        String triggerId = AdminService.platformEventSubscriberTriggerId;
        String query = new QBuilder('PlatformEventSubscriberConfig')
            .selectFields(new Set<String>{'Id','UserId', 'PlatformEventConsumerId', 'DeveloperName', 'MasterLabel','BatchSize'})
            .add(QBuilder.condition('DeveloperName').equalsTo(AdminService.PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME))
            .add(QBuilder.condition('PlatformEventConsumerId').equalsTo(triggerId))
            .addLimit(1)
            .build();
        return System.Url.getOrgDomainUrl().toExternalForm() + ConfigUtil.TOOLING_QUERY_API_51_ENDPOINT + EncodingUtil.urlEncode(query, 'UTF-8');
    }

    private static TestDataFactory.SingleRequestMock getPlatformEventConfigMock() {
        TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
            200,
            'OK',
            JSON.serialize(new Map<String, Object>{
                ConfigUtil.TOOLING_ITEMS_KEY_RECORDS => new List<Map<String, Object>>{
                    new Map<String, Object>{'Id'=>'platformEventId'}
                }
            })
        );
        return singleRequestMock;
    }

    public class YourWebServiceMockImpl implements WebServiceMock {
        private MetadataService.CaseSettings[] records;

        public YourWebServiceMockImpl(MetadataService.CaseSettings[] records) {
            this.records = records;
        }
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

            MetadataService.readCaseSettingsResponse_element metadataResponse = new MetadataService.readCaseSettingsResponse_element();
            MetadataService.ReadCaseSettingsResult result = new MetadataService.ReadCaseSettingsResult();
            result.records = this.records;
            metadataResponse.result = result;

            response.put('response_x', metadataResponse);
        }
    }

}