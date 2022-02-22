public with sharing class SetupAuditTrailViewerController {

    public Log__c log { get; set; }
    public Integer hours { get; set; }
    public String data { get; set; }

    public List<SelectOption> getHoursOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('1', '1 hour'));
        options.add(new SelectOption('12', '12 hours'));
        options.add(new SelectOption('24', '24 hours'));
        options.add(new SelectOption('48', '48 hours'));
        return options;
    }

    public SetupAuditTrailViewerController(ApexPages.StandardController stdController) {
        this.log = [
            SELECT Id, Setup_Audit_Trail__c, Created_At__c, CreatedDate
            FROM Log__c
            WHERE Id = :stdController.getId()
        ];
        data = log.Setup_Audit_Trail__c;
    }

}