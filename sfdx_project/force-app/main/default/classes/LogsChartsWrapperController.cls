global with sharing class LogsChartsWrapperController {
    public Boolean isDev { get; set; }
	public Log__c currentLog { get; set; }
	public String packageNamespace { get {return Configutil.getNameSpacePrefix();} set; }

    public LogsChartsWrapperController(ApexPages.StandardController stdController) {
        String isDevParam = ApexPages.currentPage().getParameters().get('dev');
        if (String.isNotBlank(isDevParam)) {
            isDev = Boolean.valueOf(isDevParam);
        } else {
            Cookie devCookie = ApexPages.currentPage().getCookies().get('a2developmentMode');
            isDev = devCookie != null ? Boolean.valueOf(devCookie.getValue()) : false;
		}
		currentLog = [
			SELECT Id, Name, Hash__c, Hash_1__c, Hash_2__c, Hash_3__c, Created_At__c, Summary__c, Organization_Id__c
		    FROM Log__c
			WHERE Id = :stdController.getId()
		];
    }

    @RemoteAction
	global static String remoteActionHandler(String input) {
		Map<String, Object> request = (Map<String, Object> )JSON.deserializeUntyped(input);
		RemoteActionResponse response = new RemoteActionResponse();
		response.params = request;
		String method = (String)request.get('method');
		Object data = request.get('data');
		Map<String, Object> output = new Map<String, Object>();
		Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
		try {
			if (method == 'getOccurrenceLogs') {
				Integer sd = (Integer)payload.get('showDays');
				String logId = (String)payload.get('logId');
				output.put('occurrenceLogs', JSON.deserializeUntyped(getLogs(sd, logId)));

			} else if (method == 'getTimingLogs') {
				Integer showRange = (Integer)payload.get('showRange');
				String logId = (String)payload.get('logId');
				output.put('timingLogs', JSON.deserializeUntyped(getAllLogs(showRange, logId)));

			} else {
				response.error = 'Action not found';
			}
		} catch(Exception e) {
			response.error = e.getMessage();
			response.stack = e.getStackTraceString();
			Logger.getInstance().internalError(e, LogsChartsWrapperController.class.getName(), 'remoteActionHandler');
		}
		response.data = output;
		return JSON.serialize(response);
	}

	private static String getAllLogs (Integer showRange, String currentLogId) {
		Map<String, Object> dataMap = new Map<String, Object>();
		List<Log__c> currentLogs = [
			SELECT Id, Name, Hash__c, Hash_1__c, Hash_2__c, Hash_3__c, Created_At__c, Summary__c, Organization_Id__c
			FROM Log__c
			WHERE Id = :currentLogId
		];
		if (!currentLogs.isEmpty()) {
			Datetime endDate;
			Datetime startDate;
			Datetime dt = currentLogs[0].Created_At__c;
			if (showRange == 10 || showRange == 30 || showRange == 60) {
				endDate = dt.addMinutes( 1 * Integer.valueOf(showRange));
				startDate = dt.addMinutes( -1 * Integer.valueOf(showRange));
			} else {
				endDate = dt.addMinutes(10);
				startDate = dt.addMinutes(-10);
			}
			List<Log__c> allLogs = [
					SELECT Id, Created_At__c, Hash_1__c, Summary__c
					FROM Log__c
					WHERE Hash_1__c != NULL AND
					Organization_Id__c = :currentLogs[0].Organization_Id__c AND
					Created_At__c >= :startDate AND
					Created_At__c <= :endDate
					ORDER BY Created_At__c];
			dataMap.put('allLogs', allLogs);
		}
		return JSON.serialize(dataMap);
	}

	private static String getLogs(Integer showDays, String currentLogId) {
		Map<String, Object> dataMap = new Map<String, Object>();
		Date endDate;
		Date startDate;
		if (showDays == 7 || showDays == 30 || showDays == 60 || showDays == 180) {
			endDate = Date.today();
			startDate = endDate.addDays(-1 * showDays);
		} else {
			endDate = Date.today();
			startDate = endDate.addDays(-30);
		}
		List<Log__c> currentLogs = [
			SELECT Id, Name, Hash__c, Hash_1__c, Hash_2__c, Hash_3__c, Created_At__c, Summary__c, Organization_Id__c
			FROM Log__c
			WHERE Id = :currentLogId
		];
		if (!currentLogs.isEmpty()) {
			List<Log__c> logsWithHash1 = [
					SELECT Id, Created_At__c
					FROM Log__c
					WHERE (Hash_1__c = :currentLogs[0].Hash_1__c AND
					Organization_Id__c = :currentLogs[0].Organization_Id__c AND
					Hash_1__c != NULL AND
					DAY_ONLY(Created_At__c) >= :startDate AND
					DAY_ONLY(Created_At__c) <= :endDate) OR
					Id = :currentLogs[0].Id
					ORDER BY Created_At__c];
			List<Log__c> logsWithHash2 = [
					SELECT Id, Created_At__c
					FROM Log__c
					WHERE Hash_2__c = :currentLogs[0].Hash_2__c AND
					Organization_Id__c = :currentLogs[0].Organization_Id__c AND
					Hash_2__c != NULL AND
					DAY_ONLY(Created_At__c) >= :startDate AND
					DAY_ONLY(Created_At__c) <= :endDate AND
					Id != :currentLogs[0].Id
					ORDER BY Created_At__c];
			List<Log__c> logsWithHash3 = [
					SELECT Id, Created_At__c
					FROM Log__c
					WHERE Hash_3__c = :currentLogs[0].Hash_3__c AND
					Organization_Id__c = :currentLogs[0].Organization_Id__c AND
					Hash_3__c != NULL AND
					DAY_ONLY(Created_At__c) >= :startDate AND
					DAY_ONLY(Created_At__c) <= :endDate AND
					Id != :currentLogs[0].Id
					ORDER BY Created_At__c];
			dataMap.put('hash1', logsWithHash1);
			dataMap.put('hash2', logsWithHash2);
			dataMap.put('hash3', logsWithHash3);
		}
		return JSON.serialize(dataMap);
	}

    public class RemoteActionResponse {
        public Object params;
        public Object data;
        public String error;
        public String stack;
    }

}