@IsTest
public class Test_LogService {

    public static final String CONNECTED_ORG_SETTINGS_CLIENT_KEY = 'somekey';
    public static final String CONNECTED_ORG_SETTINGS_CLIENT_SECRET = 'somesecretkey';
    public static final String LOGGER_SETTINGS_EMAIL_SERVICE_ADDRESS = 'someone@test.com';
    public static final Boolean LOGGER_SETTINGS_DEBUG_MODE = true;
    public static final String CONNECETED_ORG_NAME = '00D40000000N3x2';
    public static final String CONNECETED_ORG_TITLE = 'Test Connected Org';
    public static final String CONNECETED_ORG_DESCRIPTION = 'Test Description';
    public static final String CONNECETED_ORG_TYPE = 'production';
    public static final String CONNECETED_ORG_ACCESS_TOKEN = 'someAccessToken';
    public static final String CONNECETED_ORG_REFRESH_TOKEN = 'someRefreshToken';
    public static final DateTime CONNECETED_ORG_TOKEN_REFRESHED_AT = Datetime.now();
    public static final String CONNECETED_ORG_INSTANCE_URL = 'https://testurl.test';
    public static final String CONNECETED_ORG_IDENTITY_URL = null;

    public static String getTestStub(String name) {
        String testStub = [SELECT Body FROM StaticResource WHERE Name = 'TestStubs'].Body.toString();
        Map<String, Object> testStubMap = (Map<String, Object>)JSON.deserializeUntyped(testStub);
        return (String)testStubMap.get(name);
    }

    public static List<Object> getTestStubList(String name) {
        String testStub = [SELECT Body FROM StaticResource WHERE Name = 'TestStubs'].Body.toString();
        Map<String, Object> testStubMap = (Map<String, Object>)JSON.deserializeUntyped(testStub);
        return (List<Object>)testStubMap.get(name);
    }

    public static void initSettings() {
        Connected_Orgs_Settings__c connectedOrgsSettings = new Connected_Orgs_Settings__c(
            Client_Key__c = CONNECTED_ORG_SETTINGS_CLIENT_KEY,
            Client_Secret__c = CONNECTED_ORG_SETTINGS_CLIENT_SECRET
        );
        insert connectedOrgsSettings;

        Logger_Settings__c settings = new Logger_Settings__c(
            Email_Service_Address__c = LOGGER_SETTINGS_EMAIL_SERVICE_ADDRESS,
            Debug__c = LOGGER_SETTINGS_DEBUG_MODE
        );
        insert settings;
        
        Connected_Org__c corg = new Connected_Org__c(
            Name = CONNECETED_ORG_NAME,
            Title__c = CONNECETED_ORG_TITLE,
            Description__c = CONNECETED_ORG_DESCRIPTION,
            Type__c = CONNECETED_ORG_TYPE,
            Access_Token__c = CONNECETED_ORG_ACCESS_TOKEN,
            Refresh_Token__c = CONNECETED_ORG_REFRESH_TOKEN,
            Token_Refreshed_At__c = CONNECETED_ORG_TOKEN_REFRESHED_AT,
            Instance_Url__c = CONNECETED_ORG_INSTANCE_URL,
            Identity_Url__c = CONNECETED_ORG_IDENTITY_URL
        );
        Connected_Org__c selfCorg = new Connected_Org__c(
            Name = UserInfo.getOrganizationId().left(15),
            Instance_Url__c = System.Url.getOrgDomainUrl().toExternalForm(),
            Title__c = CONNECETED_ORG_TITLE,
            Description__c = CONNECETED_ORG_DESCRIPTION
        );
        insert new List<Connected_Org__c>{corg, selfCorg};
    }

    @IsTest
    static void test_failed_trigger () {
        initSettings();
        Test.startTest();
        String exceptionBody = String.valueOf(getTestStubList('testExceptionEmails').get(0));
        Log__c log = LogService.createLogFromEmailBody(exceptionBody, 'Test Email', 'test@test.com', Datetime.now());
        Test.stopTest();
        System.assertNotEquals(null, log);
    }

    @IsTest
    static void test_failed_batch () {
        initSettings();
        Test.startTest();
        String exceptionBody = String.valueOf(getTestStubList('testExceptionEmails').get(1));
        Log__c log = LogService.createLogFromEmailBody(exceptionBody, 'Test Email', 'test@test.com', Datetime.now());
        Test.stopTest();
        System.assertNotEquals(null, log);
    }

    @IsTest
    static void test_failed_batch_full_stack () {
        initSettings();
        Test.startTest();
        String exceptionBody = String.valueOf(getTestStubList('testExceptionEmails').get(2));
        Log__c log = LogService.createLogFromEmailBody(exceptionBody, 'Test Email', 'test@test.com', Datetime.now());
        Test.stopTest();
        System.assertNotEquals(null, log);
    }

    @IsTest
    static void test_failed_queueable_job () {
        initSettings();
        Test.startTest();
        String exceptionBody = String.valueOf(getTestStubList('testExceptionEmails').get(3));
        Log__c log = LogService.createLogFromEmailBody(exceptionBody, 'Test Email', 'test@test.com', Datetime.now());
        Test.stopTest();
        System.assertNotEquals(null, log);
    }

    @IsTest
    static void test_visualforce_exception_email () {
        initSettings();
        Test.startTest();
        Log__c log = LogService.createLogFromEmailBody(getTestStub('visualforceExceptionEmail'), 'Test Email', 'test@test.com', Datetime.now());
        Test.stopTest();
        System.assertNotEquals(null, log);
    }
}