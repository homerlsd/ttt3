global with sharing class ErrorEmailHandler implements Messaging.InboundEmailHandler {

    // GLOBAL
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email,
                                                           Messaging.InboundEnvelope env) {
        String s = email.subject;
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        Inbound_Email__c inboundEmail = (Inbound_Email__c)PermissionsUtil.newSObject(Schema.SObjectType.Inbound_Email__c);
        PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.Plain_Text__c, maskContent(email.plainTextBody));
        PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.Html_Body__c, maskContent(email.htmlBody));
        PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.Subject__c, s.abbreviate(255));
        PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.From__c, email.fromAddress + (String.isNotBlank(email.fromName) ? ' (' + email.fromName + ')' : ''));

        if(ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c) {
            PassthroughtModeService.sendInboundEmail(inboundEmail);
        }
        else {
            processEmail(new List<Inbound_Email__c>{inboundEmail});
        }

        result.success = true;
        return result;
    }

    // PUBLIC

    public static void processEmail(List<Inbound_Email__c> inboundEmails) {
        processEmail(inboundEmails, null);
    }
    public static void processEmail(List<Inbound_Email__c> inboundEmails, String incomeOrganizationId) {
        Inbound_Email__c inboundEmail = inboundEmails.get(0);

        String body;
        if (String.isNotBlank(inboundEmail.Plain_Text__c)) {
            body = inboundEmail.Plain_Text__c;
        }
        else if (String.isNotBlank(inboundEmail.Html_Body__c) && inboundEmail.Html_Body__c.startsWithIgnoreCase('<')) {
            body = inboundEmail.Html_Body__c;
        }

        try {
            if(isChangeEmail(inboundEmail.Subject__c)) {
                AdminService.handleChangeUserEmail(inboundEmail.Subject__c, inboundEmail.Plain_Text__c);
            }
            else {
                Datetime createdAt = inboundEmail.CreatedDate != null ? inboundEmail.CreatedDate : Datetime.now();
                Log__c log = LogService.createLogFromEmailBody(body, inboundEmail.Subject__c, inboundEmail.From__c, createdAt, incomeOrganizationId);
                if(log != null) {
                    PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.Log__c, log.Id);
                }
                PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.Error__c, null);
            }
        }
        catch(Exception e) {
            String fullErrorMessage = e.getMessage();
            PermissionsUtil.putSObjectField(inboundEmail, Schema.sObjectType.Inbound_Email__c.fields.Error__c, fullErrorMessage.abbreviate(131071));
        }
        PermissionsUtil.performUpsertDML(new List<Inbound_Email__c>{inboundEmail}, Schema.sObjectType.Inbound_Email__c);
    }

    public static String maskContent(String text) {
        Map<String, SensitiveDataMask__c> masks = SensitiveDataMask__c.getAll();
        for (SensitiveDataMask__c mask : masks.values()) {
            try {
                text = text.replaceAll(mask.Regex__c, '********');
            } catch(Exception e) {}
        }
        return text;
    }

    public class ErrorEmailHandlerException extends Exception {}

    private static final String CHANGE_EMAIL_SUBJECT_MARKER = 'Finish changing your Salesforce account’s email address';

    public static Boolean isChangeEmail(String subject) {
        return (String.isNotBlank(subject) && subject.containsIgnoreCase(CHANGE_EMAIL_SUBJECT_MARKER));
    }

}