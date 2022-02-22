@IsTest
private class FlowServiceTest {

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
    private static void testScreenFlowParser() {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.corg = ConnectedOrgService.getConnectedOrgById(Test_LogService.CONNECETED_ORG_NAME);

        Test.setMock(WebServiceMock.class, new YourWebServiceMockImpl(Test_LogService.getTestStub('screenFlow_JSON_all_actions', 'TestFlowStubs')));
        FlowService.Flow flow = FlowService.parseFlowStackTrace(Test_LogService.getTestStub('screenFlow_Stacktrace', 'TestFlowStubs'));
        System.assertNotEquals(null, flow);
        System.assertNotEquals(null, flow.elements);
        System.assertNotEquals(null, flow.edges);

        Test.stopTest();
    }

    @IsTest
    private static void testAutolaunchedFlowParser() {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.corg = ConnectedOrgService.getConnectedOrgById(Test_LogService.CONNECETED_ORG_NAME);

        Test.setMock(WebServiceMock.class, new YourWebServiceMockImpl(Test_LogService.getTestStub('autolaunchedFlow_JSON', 'TestFlowStubs')));
        FlowService.Flow flow = FlowService.parseFlowStackTrace(Test_LogService.getTestStub('autolaunchedFlow_Stacktrace', 'TestFlowStubs'));
        System.assertNotEquals(null, flow);
        System.assertNotEquals(null, flow.elements);
        System.assertNotEquals(null, flow.edges);

        Test.stopTest();
    }

    @IsTest
    private static void testAutolaunchedFlowExecutionPath() {

        Test_LogService.initSettings();

        Test.startTest();

        StackTraceParser.corg = ConnectedOrgService.getConnectedOrgById(Test_LogService.CONNECETED_ORG_NAME);
        String htmlStacktrace = Test_LogService.getTestStub('autolaunchedFlow_Stacktrace', 'TestFlowStubs');
        Test.setMock(WebServiceMock.class, new YourWebServiceMockImpl(Test_LogService.getTestStub('autolaunchedFlow_JSON', 'TestFlowStubs')));
        FlowService.Flow flow = FlowService.parseFlowStackTrace(htmlStacktrace);
        System.assertNotEquals(null, flow);
        System.assertNotEquals(null, flow.elements);
        System.assertNotEquals(null, flow.edges);

        List<String> executionPath = FlowService.getFlowExecutionPath(htmlStacktrace);
        System.assertNotEquals(null, executionPath);
        System.assertNotEquals(0, executionPath.size());

        Test.stopTest();
    }
}