global with sharing class StacktraceViewerController {

	public Log__c log { get; set; }
	public String packageNamespace { get {return Configutil.getNameSpacePrefix();} set; }
	public Boolean isDev { get; set; }


	public StacktraceViewerController(ApexPages.StandardController stdController) {
		this.log = [
			SELECT Id, Name, Stacktrace__c, Stacktrace_Parse_Result__c, Type__c, Summary__c, Organization_Url__c, Category__c, Async_Job_Id__c
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

	@RemoteAction
	global static String remoteActionHandler(String input) {
		String result;
		String methodName;
		String method;
		RemoteActionResponse response = new RemoteActionResponse();
		try {
			Map<String, Object> request = (Map<String, Object> )JSON.deserializeUntyped(input);
			response.params = request;
			method = (String)request.get('method');
			methodName = method;
			Object data = request.get('data');
			if (method == 'getContentDocumentIds') {
				response.data = getContentDocumentIds(data);
			} else if (method == 'getAppPermissions') {
				response.data = AdminService.getAppPermissions(data);
			} else if (method == 'replayCallout') {
				response.data = replayCallout(data);
			} else {
				response.error = 'Action not found';
			}
			result = JSON.serialize(response);
		}
		catch(Exception e) {
			response.error = e.getMessage();
			response.stack = e.getStackTraceString();
			if(method != 'replayCallout') {
				Logger.getInstance().internalError(e, StacktraceViewerController.class.getName(), 'remoteActionHandler' + (String.isNotBlank(methodName) ? '.' + methodName : ''));
			}
		}
		finally {
			try {
				result = JSON.serialize(response);
			}
			catch(Exception e) {
				if(method != 'replayCallout') {
					Logger.getInstance().internalError(e, StacktraceViewerController.class.getName(), 'remoteActionHandler.serializeResponse');
				}
			}
		}
		return result;
	}

	private static Set<String> getContentDocumentIds(Object data) {
		Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
		String logId = (String)payload.get('logId');
		return new Map<String, AggregateResult>([SELECT ContentDocumentId Id FROM ContentDocumentLink WHERE LinkedEntityId = :logId GROUP BY ContentDocumentId]).keySet();
	}

	private static Map<String, Object> replayCallout(Object data) {
		Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
		String endpoint = (String)payload.get('endpoint');
		String method = (String)payload.get('method');
		Map<String, String> headers = new Map<String, String>();
		if (payload.get('headers') != null) {
			Map<String, Object> mapHeaders = (Map<String, Object>)payload.get('headers');
			for (String key : mapHeaders.keySet()) {
				headers.put(key, String.valueOf(mapHeaders.get(key)));
			}
		}
		String body = (String)payload.get('body');
		HttpResponse res = HttpUtils.send(endpoint, method, headers, body);
		return new HttpResponseWrapper(res).formatResponse();
	}

	public class RemoteActionResponse {
		public Object params;
		public Object data;
		public String error;
		public String stack;
	}
}