public with sharing class DeployResultsViewerController {

    public Log__c log { get; set; }
    public String corgBaseUrl { get; set; }
    public Integer timeZoneOffset { get; set; }

    public DeployResultsViewerController(ApexPages.StandardController stdController) {
        this.log = [
            SELECT Id, Deploy_Results__c, Organization_Id__c
            FROM Log__c
            WHERE Id = :stdController.getId()
        ];

        corgBaseUrl = '';
        if (String.isNotBlank(log.Organization_Id__c)) {
            Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(log.Organization_Id__c);
            if (corg != null) {
                corgBaseUrl = corg.Instance_Url__c;
            }
        }

        timeZoneOffset = AdminService.getUserTimezoneOffset();

    }

}