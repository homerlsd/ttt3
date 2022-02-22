@isTest
public class Test_StackTraceParser {

    public static String stackTrace1 = '' +
    'Class.System.JSON.deserialize: line 15, column 1\n' +
    'Class.StackTraceParser.getClassesMap: line 39, column 1\n' +
    'AnonymousBlock: line 42, column 1\n' +
    'AnonymousBlock: line 42, column 1';

    public static String stackTrace2 = '' +
    'Class.SBQQ.QuoteService: line 336, column 1\n' +
    'Class.SBQQ.QuoteService: line 273, column 1\n' +
    'Class.SBQQ.QuoteService: line 269, column 1\n' +
    'Class.SBQQ.QuoteService: line 216, column 1\n' +
    'Class.SBQQ.QueueableCalculatorService.CalculateSyncher: line 242, column 1\n' +
    'Class.SBQQ.QueueableCalculatorService.execute: line 58, column 1';

    public static String stackTrace3 = '' +
    'Class.SBQQ.RestClient.send: line 77, column 1\n' +
    'Class.SBQQ.RestClient.post: line 43, column 1\n' +
    'Class.SBQQ.JSQCClient.calculate: line 72, column 1\n' +
    'Class.SBQQ.QuoteService.calculate: line 303, column 1\n' +
    'Class.SBQQ.QuoteService.calculate: line 273, column 1\n' +
    'Class.SBQQ.QuoteService.calculate: line 269, column 1\n' +
    'Class.SBQQ.QuoteService.calculateAndSynch: line 216, column 1\n' +
    'Class.SBQQ.QuoteService.calculateAndSynch: line 222, column 1\n' +
    'Trigger.SBQQ.QuoteAfter: line 45, column 1';

    public static String stackTrace4 = '' +
    'Trigger.LoggerTest1.LogTrigger: line 3, column 1';


    static testMethod void test1 () {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.ApexClassesResponseWrapper resp = new StackTraceParser.ApexClassesResponseWrapper();
        resp.size = 1;
        resp.records = new List<StackTraceParser.ApexClassWrapper>();
        StackTraceParser.ApexClassWrapper c1 = new StackTraceParser.ApexClassWrapper();
        c1.Id = 'Id';
        c1.Name = 'TestClass';
        c1.Body = 'test class body here ...';
        resp.records.add(c1);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(JSON.serialize(resp), 200));

        StackTraceParser.corg = ConnectedOrgService.getConnectedOrgById('00D40000000N3x2');

        System.assertNotEquals(StackTraceParser.corg, null);

        List<StackTraceParser.StackTraceParseResult> result = StackTraceParser.parseStackTrace(stackTrace1);

        System.assertEquals(4, result.size());

        Test.stopTest();

    }

    static testMethod void test2 () {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.ApexClassesResponseWrapper resp = new StackTraceParser.ApexClassesResponseWrapper();
        resp.size = 1;
        resp.records = new List<StackTraceParser.ApexClassWrapper>();
        StackTraceParser.ApexClassWrapper c1 = new StackTraceParser.ApexClassWrapper();
        c1.Id = 'Id';
        c1.Name = 'TestClass';
        c1.Body = 'test class body here ...';
        resp.records.add(c1);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(JSON.serialize(resp), 200));

        Log__c log = new Log__c(
            Details__c = stackTrace3,
            Stacktrace__c = stackTrace3
        );
        insert log;

        Test.stopTest();

        System.assertNotEquals(null, log.Stacktrace__c);
    }

    public class MockHttpResponseGenerator implements HttpCalloutMock {

        public Integer testResponseCode = 200;
        public String testResponse = null;

        public MockHttpResponseGenerator(String testResponse, Integer testResponseCode) {
            this.testResponse = testResponse;
            this.testResponseCode = testResponseCode;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.testResponse);
            res.setStatusCode(this.testResponseCode);
            return res;
        }
    }

    public class YourWebServiceMockImpl implements WebServiceMock {
        private String jsonData;

        public YourWebServiceMockImpl(String jsonData) {
            this.jsonData = jsonData;
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

            MetadataService.readFlowResponse_element metadataResponse = new MetadataService.readFlowResponse_element();
            MetadataService.ReadFlowResult result = (MetadataService.ReadFlowResult)JSON.deserialize(this.jsonData, MetadataService.ReadFlowResult.class);
            metadataResponse.result = result;

            response.put('response_x', metadataResponse);
        }
    }

    @IsTest
    private static void testFlowParser() {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.corg = ConnectedOrgService.getConnectedOrgById(Test_LogService.CONNECETED_ORG_NAME);

        Test.setMock(WebServiceMock.class, new YourWebServiceMockImpl(Test_LogService.getTestStub('flowJSON_all_actions')));
        FlowService.Flow flow = FlowService.parseFlowStackTrace(Test_LogService.getTestStub('flow_AllActions_StackTrace'));
        System.assertNotEquals(null, flow);
        System.assertNotEquals(null, flow.elements);
        System.assertNotEquals(null, flow.edges);

        Test.stopTest();
    }

    @IsTest
    private static void testProcessBuilderParser() {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.corg = ConnectedOrgService.getConnectedOrgById(Test_LogService.CONNECETED_ORG_NAME);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(Test_LogService.getTestStub('processBuilderJSON_ResponseNameGroupCall'), 200));
        Test.setMock(WebServiceMock.class, new YourWebServiceMockImpl(Test_LogService.getTestStub('processBuilderJSON_all_actions')));
        FlowService.ProcessBuilder processBuilder = FlowService.parseProcessBuilderStackTrace(Test_LogService.getTestStub('processBuilder_AllActions_StackTrace'));
        System.assertNotEquals(null, processBuilder);
        System.assertNotEquals(null, processBuilder.decisions);
        System.assertEquals(3, processBuilder.decisions.size());

        System.assertEquals(3, processBuilder.start.sections.size());
        System.assertEquals(FlowService.SideBarItemType.TEXT, processBuilder.start.sections.get(0).itemType);
        System.assertEquals(FlowService.SideBarItemType.RADIOBUTTON, processBuilder.start.sections.get(1).itemType);
        System.assertEquals(FlowService.SideBarItemType.CHECKBOX, processBuilder.start.sections.get(2).itemType);

        System.assertEquals('Account', processBuilder.start.sections.get(0).value);
        System.assertEquals(FlowService.PB_LABEL_OBJECT, processBuilder.start.sections.get(0).label);

        // myVaraible info
        System.assertNotEquals(null, processBuilder.context.get(FlowService.PB_ST_COMMON_VAR_NAME));

        // start sidebar info
        for(FlowService.SideBarSection sbs : processBuilder.start.sections) {
            System.assertNotEquals(null, sbs.itemType);
            System.assertNotEquals(null, sbs.label);
        }

        // decisions info
        for(FlowService.ProcessBuilderDecision pbd : processBuilder.decisions) {

            System.assertNotEquals(null, pbd.label);
            System.assertNotEquals(null, pbd.name);
            System.assertNotEquals(null, pbd.executed);
            System.assertNotEquals(null, pbd.index);

            // decisions sidebar info
            for(FlowService.SideBarSection sbs : pbd.sections) {
                System.assertNotEquals(null, sbs.itemType);
                System.assertNotEquals(null, sbs.label);
            }

            // decisions actions info
            for(List<FlowService.ProcessBuilderAction> pbaList : pbd.actions) {

                for(FlowService.ProcessBuilderAction pba : pbaList) {
                    System.assertNotEquals(null, pba.name);
                    System.assertNotEquals(null, pba.label);
                    System.assertNotEquals(null, pba.actionType);
                    System.assertNotEquals(null, pba.executed);

                    // decisions actions sidebar info
                    for(FlowService.SideBarSection sbs : pba.sections) {
                        System.assertNotEquals(null, sbs.itemType);
                        System.assertNotEquals(null, sbs.label);
                    }
                }
            }
        }

        Test.stopTest();
    }

    @IsTest
    private static void testTruncateAuditTrailItems() {
        List<Object> testItems = new List<Object>();
        for(Integer i = 0; i<100; i++){
            testItems.add(new Map<String, Object>{'Name' => 'TestLine' + i});
        }
        Integer testItemsSize = JSON.serialize(testItems).length();
        Integer maxTestItemsSize = Integer.valueOf(testItemsSize * 0.91);

        List<Object> resultTestItems;
        Integer resultItemsSize;

        Test.startTest();
        resultTestItems = LogPostProcessingService.truncateItems(maxTestItemsSize, testItems);
        resultItemsSize = JSON.serialize(resultTestItems).length();
        Test.stopTest();

        System.assertNotEquals(null, resultItemsSize);
        System.assertEquals(true, resultItemsSize < testItemsSize);
        System.assertEquals(true, resultItemsSize <= maxTestItemsSize);
    }

}