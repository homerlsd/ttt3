global with sharing class LogBuilder {

	private final Log__c log;

	private static final Integer MAX_LENGTH_TEXT_FIELD = 255;

	global static LogBuilder getInstance() {
		return new LogBuilder();
	}

	private LogBuilder() {
		log = (Log__c)PermissionsUtil.newSObject(Schema.sObjectType.Log__c);
	}

	global LogBuilder type(String value) {
		PermissionsUtil.putSObjectField(this.log, Schema.sObjectType.Log__c.fields.Type__c, value);
		return this;
	}

	global LogBuilder summary(String value) {
		PermissionsUtil.putSObjectField(this.log, Schema.sObjectType.Log__c.fields.Summary__c, String.isEmpty(value) ? null : value.abbreviate(MAX_LENGTH_TEXT_FIELD));
		return this;
	}

	global LogBuilder details(String value) {
		PermissionsUtil.putSObjectField(this.log, Schema.sObjectType.Log__c.fields.Details__c, value);
		return this;
	}

	global LogBuilder category(String value) {
		PermissionsUtil.putSObjectField(this.log, Schema.sObjectType.Log__c.fields.Category__c, value);
		return this;
	}

	global LogBuilder stackTrace(String value) {
		PermissionsUtil.putSObjectField(this.log, Schema.sObjectType.Log__c.fields.Stacktrace__c, value);
		return this;
	}

	global LogBuilder area(String value) {
		PermissionsUtil.putSObjectField(this.log, Schema.sObjectType.Log__c.fields.Area__c, value);
		return this;
	}

	global LogBuilder attribute(String field, Object value) {
		PermissionsUtil.putSObjectField(this.log, field, value);
		return this;
	}

	global Log__c build() {
		return log;
	}

}