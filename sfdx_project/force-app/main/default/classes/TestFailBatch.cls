public  class TestFailBatch implements Database.Batchable<SObject>, Database.RaisesPlatformEvents {

	public Database.QueryLocator start(Database.BatchableContext bc) {
		Database.QueryLocator queryLocator = Database.getQueryLocator([
			SELECT Id, CreatedDate FROM Contact
		]);
		return queryLocator;
	}

	public void execute(Database.batchableContext info, List<SObject> scope) {
		List<Contact> contacts = (List<Contact>)scope;
		contacts.get(0).put('CreatedDate', System.now());
		update contacts;
	}

	public void finish(Database.batchableContext inf) {
		System.setPassword('1231231231','13212312');
	}
}