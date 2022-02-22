public with sharing class EventRecordDetailsController {

    public String eventJson { get; set; }
    public String logData { get; set; }
    public Boolean isDev { get; set; }
    public String packageNamespace { get {return Configutil.getNameSpacePrefix();} set; }
    public static String baseUrl { get{
        return System.URL.getSalesforceBaseUrl().toExternalForm();
    } set; }

    public EventRecordDetailsController(ApexPages.StandardController stdController) {
        String isDevParam = ApexPages.currentPage().getParameters().get('dev');
        if (String.isNotBlank(isDevParam)) {
            Cookie devCookie = new Cookie('a2developmentMode', isDevParam, null, -1, false);
            // ApexPages.currentPage().setCookies(new Cookie[]{ devCookie });
            isDev = Boolean.valueOf(isDevParam);
        } else {
            Cookie devCookie = ApexPages.currentPage().getCookies().get('a2developmentMode');
            isDev = devCookie != null ? Boolean.valueOf(devCookie.getValue()) : false;
        }

        Event__c event = [
            SELECT Id, Name, Records__c
            FROM Event__c
            WHERE Id = :stdController.getId()
        ];


        eventJson = JSON.serialize(event);
        logData = EventsChartsWrapperController.getLogsJson(event.Records__c);
    }
}