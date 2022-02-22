@RestResource(urlMapping='/chargify/*')
global with sharing class ChargifyRestService {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        System.debug('---'+json.serialize(req));
        System.debug('---' + req.requestBody.toString());
        System.debug('---1-'+JSON.serialize(RestContext.request.params));
        System.debug('---2-'+JSON.serialize(RestContext.request.params.keySet()));

        res.responseBody = Blob.valueOf('OK');
        res.statusCode = 200;

    
    }

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        //GetLogResult result = new GetLogResult();
        Blob responseData = null;
        System.debug('---'+json.serialize(req));

        Map<String, String> params = (req != null && req.params != null) ? req.params : new Map<String, String>();
        //result = new GetLogResult(params);
        //responseData = Blob.valueOf(JSON.serialize(result));

        res.responseBody = null;//responseData;
        res.statusCode = 200;//result.statusCode;
    }
}