public with sharing class JiraDetailsController {

    public string jiraTaskUrl { get; set; }
    public string jiraTask { get; set; }
    public Log__c log { get; set; }

    public JiraDetailsController(ApexPages.StandardController stdController) {
        this.log = [
            SELECT Id, Bug_Tracker__c, Hash_1__c
            FROM Log__c
            WHERE Id = :stdController.getId()
        ];
        this.jiraTaskUrl = this.log.Bug_Tracker__c;
    }

    public void init() {
        try {
            String taskKey = JiraService.getIssueKeyByUrl(this.jiraTaskUrl);
            this.jiraTask = JSON.serializePretty(
                                JSON.deserializeUntyped(
                                    JiraService.getIssueDetailsByKey(
                                        taskKey
                                    )));
        } catch(Exception e) {
            this.jiraTask = e.getMessage();
        }
    }

}