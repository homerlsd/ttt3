public with sharing class BatchApexErrorEventTriggerHandler {

	public enum Area {
		Apex,
		Workflow,
		Flow,
		ProcessBuilder
	}

	public enum Category {
		Error,
		Warning,
		Event,
		Debug
	}

	public static void handleErrorEvents(List<BatchApexErrorEvent> errorEvents) {
		Set<Id> asyncApexJobIds = new Set<Id>();
		for(BatchApexErrorEvent evt : errorEvents) {
			asyncApexJobIds.add(evt.AsyncApexJobId);
		}

		Map<Id, AsyncApexJob> jobs = new Map<Id, AsyncApexJob>(
			[SELECT Id, ApexClass.Name, ApexClass.NamespacePrefix FROM AsyncApexJob WHERE Id IN :asyncApexJobIds]
		);

		for(BatchApexErrorEvent evt : errorEvents) {
			String logRelatedId = null;
			Boolean isPharosError = jobs.get(evt.AsyncApexJobId) != null
				&& jobs.get(evt.AsyncApexJobId) != null
				&& jobs.get(evt.AsyncApexJobId).ApexClass != null
				&& jobs.get(evt.AsyncApexJobId).ApexClass.NamespacePrefix != null
				&& jobs.get(evt.AsyncApexJobId).ApexClass.NamespacePrefix == ConfigUtil.NS;

			String jobName = jobs.get(evt.AsyncApexJobId) != null
				? jobs.get(evt.AsyncApexJobId).ApexClass.Name
				: null;
			if(String.isNotBlank(evt.JobScope)) {
				for(String item : evt.JobScope.split(',')) {
					logRelatedId = item;
					break;
				}
			}

			Log__c log = LogBuilder.getInstance()
				.category(isPharosError ? Logger.CATEGORY_PHAROS_ERROR : Category.Error.name())
				.summary(evt.Message)
				.area(isPharosError ? Logger.AREA_PHAROS_ERROR : Area.Apex.name())
				.type(evt.ExceptionType)
				.stackTrace(evt.StackTrace)
				.details(evt.Phase + '\n\n' + evt.Message + '\n\n' + evt.StackTrace)
				.attribute('Related_Id__c', logRelatedId)
				.attribute('Organization_Id__c', UserInfo.getOrganizationId())
				.attribute('Async_Job_Id__c', evt.AsyncApexJobId)
				.attribute('Async_Job_Name__c', jobName)
				.build();

			Logger.getInstance().add(log);
		}
		Logger.getInstance().flush();
	}
}