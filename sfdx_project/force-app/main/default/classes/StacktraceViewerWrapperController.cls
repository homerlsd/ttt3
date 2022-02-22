public with sharing class StacktraceViewerWrapperController {

    public Log__c log { get; set; }
	public String packageNamespace { get {return Configutil.getNameSpacePrefix();} set; }
	public Boolean isDev { get; set; }

	public StacktraceViewerWrapperController(ApexPages.StandardController stdController) {
		this.log = [
			SELECT Id, Name, Stacktrace__c, Stacktrace_Parse_Result__c, Type__c
			FROM Log__c
			WHERE Id = :stdController.getId()
		];
		String isDevParam = ApexPages.currentPage().getParameters().get('dev');
		if (String.isNotBlank(isDevParam)) {
			Cookie devCookie = new Cookie('a2developmentMode', isDevParam, null, -1, false);
			// ApexPages.currentPage().setCookies(new Cookie[]{ devCookie });
			isDev = Boolean.valueOf(isDevParam);
		} else {
			Cookie devCookie = ApexPages.currentPage().getCookies().get('a2developmentMode');
			isDev = devCookie != null ? Boolean.valueOf(devCookie.getValue()) : false;
		}
	}
}