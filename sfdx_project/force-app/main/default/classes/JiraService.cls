public without sharing class JiraService {

    public static ConnectedOrgService.AuthTokenResponse getJiraAPIToken(String authCode, String clientId, String clientSecret, String endpoint) {
        Map<String, Object> body = new Map<String, Object>{
            'grant_type' => 'authorization_code',
            'client_id' => clientId,
            'client_secret' => clientSecret,
            'code' => authCode,
            'redirect_uri' => LoggerSettingsController.PHAROS_OUATH_CALLBACK_PROXY
        };
        String b = HttpUtils.post(
            endpoint ,
            json.serialize(body),
            HttpUtils.getHeadersContentTypeJSON(),
            200
        );

        ConnectedOrgService.AuthTokenResponse resp = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);
        return resp;
    }

    public static ConnectedOrgService.AuthTokenResponse getJiraRefreshAPIToken(String refreshToken, String clientId, String clientSecret, String endpoint) {
        Map<String, Object> body = new Map<String, Object>{
            'grant_type' => 'refresh_token',
            'client_id' => clientId,
            'client_secret' => clientSecret,
            'refresh_token' => refreshToken
        };
        String b = HttpUtils.post(
            endpoint ,
            json.serialize(body),
            HttpUtils.getHeadersContentTypeJSON(),
            200
        );

        ConnectedOrgService.AuthTokenResponse resp = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);
        return resp;
    }

    public static ConfigUtil.JiraResourceWrapper getJiraAvailableResources(String accessToken) {
        String b = HttpUtils.get(
            ConfigUtil.JIRA_CLOUD_API_RESOURCES_ENDPOINT,
            HttpUtils.getHeadersAuthorizationAcceptJson('Bearer ' + accessToken),
            200
        );
        List<ConfigUtil.JiraResourceWrapper> resp = (List<ConfigUtil.JiraResourceWrapper>)JSON.deserialize(b, List<ConfigUtil.JiraResourceWrapper>.class);
        return resp.get(0);
    }

    @Future(Callout = true)
    public static void validateAndRefreshJiraOauthTokenFuture() {
        validateAndRefreshJiraOauthToken();
    }

    public static void validateAndRefreshJiraOauthToken() {
        validateAndRefreshJiraOauthToken(true);
    }

    public static void validateAndRefreshJiraOauthToken(Boolean withDML) {
        if(ConfigUtil.JIRA_SETTINGS.Jira_Username__c == ConfigUtil.JIRA_CLOUD_OAUTH_USERNAME) {

            try {
                ConfigUtil.JiraResourceWrapper resources = getJiraAvailableResources(ConfigUtil.JIRA_OAUTH_TOKEN);
            }
            catch(HttpUtils.HttpUtilsException e) {
                // token expired, refresh OAuth Token

                OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(ConfigUtil.JIRA_CLOUD_SETTINGS_NAME);
                String clientId = mdtSettings.Client_Id__c;
                String clientSecret = mdtSettings.Client_Secret__c;
                String endpoint = ConfigUtil.JIRA_CLOUD_OAUTH_ENDPOINT;

                try {
                    ConnectedOrgService.AuthTokenResponse refreshOauthToken = getJiraRefreshAPIToken(ConfigUtil.JIRA_OAUTH_REFRESH_TOKEN, clientId, clientSecret, endpoint);
                    JiraService.putEncryptedJiraTokenToCache(ConfigUtil.JIRA_SETTINGS, refreshOauthToken.access_token);
                    JiraService.putEncryptedJiraRefreshTokenToCache(ConfigUtil.JIRA_SETTINGS, refreshOauthToken.refresh_token);

                    JiraService.splitToken(refreshOauthToken.access_token);
                    ConfigUtil.JIRA_SETTINGS.Refresh_Token__c = refreshOauthToken.refresh_token;
                    if(withDML) {
                        upsert ConfigUtil.JIRA_SETTINGS;
                    }
                }
                catch(Exception exc) {
                    Logger.getInstance().internalError(exc, null, true, JiraService.class.getName(), 'getJiraRefreshAPIToken');
                }
            }
        }
    }

    public static final Integer CUSTOM_SETTINGS_FILED_MAX_SIZE = 255;
    public static void splitToken(String token) {
        Integer tokenLength = token.length();
        if(tokenLength > 5*CUSTOM_SETTINGS_FILED_MAX_SIZE){
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,3*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token4__c = token.subString(3*CUSTOM_SETTINGS_FILED_MAX_SIZE,4*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token5__c = token.subString(4*CUSTOM_SETTINGS_FILED_MAX_SIZE,5*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token6__c = token.subString(5*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
        }
        else if(tokenLength > 4*CUSTOM_SETTINGS_FILED_MAX_SIZE){
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,3*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token4__c = token.subString(3*CUSTOM_SETTINGS_FILED_MAX_SIZE,4*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token5__c = token.subString(4*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
        }
        else if(tokenLength > 3*CUSTOM_SETTINGS_FILED_MAX_SIZE){
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,3*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token4__c = token.subString(3*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
        }
        else if(tokenLength > 2*CUSTOM_SETTINGS_FILED_MAX_SIZE){
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
        }
        else if(tokenLength > CUSTOM_SETTINGS_FILED_MAX_SIZE){
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
        }
        else if(tokenLength > 0){
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = token.subString(0,tokenLength);
        }
    }

    public static String getAlphanumericString(String input) {
        Pattern nonAlphanumeric = Pattern.compile('[^a-zA-Z0-9]');
        Matcher matcher = nonAlphanumeric.matcher(input);
        String result = matcher.replaceAll('');
        return result;
    }

    public static String getJiraInstanceKey(String jiraInstance) {
        return EncodingUtil.base64Encode(Crypto.generateDigest('SHA3-256', Blob.valueOf(String.valueOf(jiraInstance))));
    }

    public static void putEncryptedJiraTokenToCache(Jira_Settings__c jiraSettings, String token) {
        try {
            if (String.isNotBlank(token)) {
                String keyCache = CacheUtils.buildCacheKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_TOKEN, getAlphanumericString(jiraSettings.Jira_Base_Url__c), '');
                Boolean isCacheAvailableForKey = CacheUtils.isCacheAvailableForKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_TOKEN, keyCache);
                if (isCacheAvailableForKey) {
                    Blob encryptedToken = Crypto.encryptWithManagedIV('AES256', EncodingUtil.base64Decode(getJiraInstanceKey(getAlphanumericString(jiraSettings.Jira_Base_Url__c))), Blob.valueOf(token));
                    CacheUtils.putCacheValue(keyCache, encryptedToken, CacheUtils.getTTLValue(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_TOKEN));
                }
            }
        } catch (Exception e) {
            Logger.getInstance().internalError(e, jiraSettings.Jira_Base_Url__c, true, ConnectedOrgService.class.getName(), 'putEncryptedJiraTokenToCache');
        }
    }

    public static void putEncryptedJiraRefreshTokenToCache(Jira_Settings__c jiraSettings, String refreshToken) {
        try {
            if (String.isNotBlank(refreshToken)) {
                String keyCache = CacheUtils.buildCacheKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_REFRESH_TOKEN, getAlphanumericString(jiraSettings.Jira_Base_Url__c), '');
                Boolean isCacheAvailableForKey = CacheUtils.isCacheAvailableForKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_REFRESH_TOKEN, keyCache);
                if (isCacheAvailableForKey) {
                    Blob encryptedToken = Crypto.encryptWithManagedIV('AES256', EncodingUtil.base64Decode(getJiraInstanceKey(getAlphanumericString(jiraSettings.Jira_Base_Url__c))), Blob.valueOf(refreshToken));
                    CacheUtils.putCacheValue(keyCache, encryptedToken, CacheUtils.getTTLValue(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_REFRESH_TOKEN));
                }
            }
        } catch (Exception e) {
            Logger.getInstance().internalError(e, jiraSettings.Jira_Base_Url__c, true, ConnectedOrgService.class.getName(), 'putEncryptedJiraRefreshTokenToCache');
        }
    }

    public static String getDecryptedJiraTokenFromCache() {
        try {
            String keyCache = CacheUtils.buildCacheKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_TOKEN, getAlphanumericString(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c), '');
            Boolean isCacheAvailableForKey = CacheUtils.isCacheAvailableForKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_TOKEN, keyCache);
            if (isCacheAvailableForKey) {
                Object cacheObject = CacheUtils.getCacheValue(keyCache);
                if (cacheObject != null) {
                    Blob decryptedToken = Crypto.decryptWithManagedIV('AES256', EncodingUtil.base64Decode(getJiraInstanceKey(getAlphanumericString(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c))), (Blob)cacheObject);
                    return decryptedToken.toString();
                }
            }
        } catch (Exception e) {
            Logger.getInstance().internalError(e, ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c, true, ConnectedOrgService.class.getName(), 'getDecryptedJiraTokenFromCache');
        }
        return null;
    }

    public static String getDecryptedJiraRefreshTokenFromCache() {
        try {
            String keyCache = CacheUtils.buildCacheKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_REFRESH_TOKEN, getAlphanumericString(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c), '');
            Boolean isCacheAvailableForKey = CacheUtils.isCacheAvailableForKey(CacheUtils.KEY_REQUEST_ENCRYPTED_JIRA_REFRESH_TOKEN, keyCache);
            if (isCacheAvailableForKey) {
                Object cacheObject = CacheUtils.getCacheValue(keyCache);
                if (cacheObject != null) {
                    Blob decryptedToken = Crypto.decryptWithManagedIV('AES256', EncodingUtil.base64Decode(getJiraInstanceKey(getAlphanumericString(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c))), (Blob)cacheObject);
                    return decryptedToken.toString();
                }
            }
        } catch (Exception e) {
            Logger.getInstance().internalError(e, ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c, true, ConnectedOrgService.class.getName(), 'getDecryptedJiraRefreshTokenFromCache');
        }
        return null;
    }

    public static ConfigUtil.JiraResourceWrapper getJiraEndpoint(String token) {
        String b = HttpUtils.get(
            ConfigUtil.JIRA_CLOUD_API_RESOURCES_ENDPOINT,
            HttpUtils.getHeadersAuthorizationAcceptJson('Bearer ' + token),
            200
        );
        List<ConfigUtil.JiraResourceWrapper> resp = (List<ConfigUtil.JiraResourceWrapper>)JSON.deserialize(b, List<ConfigUtil.JiraResourceWrapper>.class);
        return resp.get(0);
    }

    public static List<JiraPriority> getPriorities() {
        List<JiraPriority> result = new List<JiraPriority>();
        String b = HttpUtils.get(
            ConfigUtil.GET_PRIORITIES_ENDPOINT,
            ConfigUtil.JIRA_HEADERS,
            200
        );
        result = (List<JiraPriority>)JSON.deserialize(b, List<JiraPriority>.class);
        return result;
    }

    public static final Set<String> SKIP_JIRA_ISSUE_TYPES = new Set<String>{'Epic','Sub-task'};
    public static List<JiraProjectMeta> getProjects() {
        List<JiraProjectMeta> result = new List<JiraProjectMeta>();
        validateConnectionToJira();
        String b = HttpUtils.get(
            ConfigUtil.GET_PROJECTS_ENDPOINT,
            ConfigUtil.JIRA_HEADERS,
            200
        );
        result = ((JiraProjectMetaList)JSON.deserialize(b, JiraProjectMetaList.class)).projects;
        for(JiraProjectMeta jp : result) {
            removeJiraIssueTypes(jp);
        }
        return result;
    }

    public static void removeJiraIssueTypes(JiraProjectMeta jp) {
        if(jp.issueTypes != null && !jp.issueTypes.isEmpty()) {
            for(Integer i = 0; i < jp.issueTypes.size(); i++) {
                if(SKIP_JIRA_ISSUE_TYPES.contains(jp.issueTypes.get(i).untranslatedName)) {
                    jp.issueTypes.remove(i);
                }
            }
        }
    }

    public static JiraProjectMeta getProject(String projectId) {
        JiraProjectMeta result = new JiraProjectMeta();
        String b = HttpUtils.get(
            ConfigUtil.GET_PROJECT_ENDPOINT + projectId,
            ConfigUtil.JIRA_HEADERS,
            200
        );
        result = (JiraProjectMeta)JSON.deserialize(b, JiraProjectMeta.class);
        removeJiraIssueTypes(result);
        return result;
    }

    public static List<JiraUser> getProjectAssignableUsers(String projectId) {

        List<JiraUser> result;
        try {
            validateConnectionToJira();
            String projectKey = getProject(projectId).key;
            String b = HttpUtils.get(
                ConfigUtil.GET_PROJECT_ASSINABLE_USERS_ENDPOINT + projectKey,
                ConfigUtil.JIRA_HEADERS,
                200
            );
            result = (List<JiraUser>)JSON.deserialize(b, List<JiraUser>.class);
            for(JiraUser ju : result) {
                if(ju.accountId == null && ju.name != null) {
                    ju.accountId = ju.name;
                }
            }
        }
        catch(Exception e) {
            result = new List<JiraUser>();
        }
        return result;
    }

    public static List<Epic> getEpics(String projectId) {
        validateConnectionToJira();
        List<JiraProjectMeta> projects = getProjects();
        JiraProjectMeta project;
        for (JiraProjectMeta p : projects) {
            if (p.id == projectId) {
                project = p;
                break;
            }
        }
        if (project == null) {
            throw new JiraServiceException('Project with Id ' + projectId + ' not found.');
        }
        String jql = 'project="'+projectId+'" AND issuetype="Epic"';
        HttpUtils.HttpURLParameters queryParams = new HttpUtils.HttpURLParameters();
        queryParams.addEncodedParameter('jql', jql);
        String b = HttpUtils.get(
                ConfigUtil.JQL_ENDPOINT + queryParams.toStringParameters('?'),
                ConfigUtil.JIRA_HEADERS,
                200
        );
        Map<String, Object> resp = (Map<String, Object>)JSON.deserializeUntyped(b);
        return (List<Epic>)JSON.deserialize(JSON.serialize(resp.get('issues')), List<Epic>.class);
    }

    public static JiraIssue getIssueInJiraByHashe2(String hash2, String jiraProjectId) {
        validateConnectionToJira();
        String jql = 'project = \''+jiraProjectId+'\' AND labels = \'h2_'+hash2+'\' AND statusCategory != \'done\' ORDER BY created ASC';
        HttpUtils.HttpURLParameters queryParams = new HttpUtils.HttpURLParameters();
        queryParams.addEncodedParameter('jql', jql);
        String b = HttpUtils.get(
                ConfigUtil.JQL_ENDPOINT + queryParams.toStringParameters('?'),
                ConfigUtil.JIRA_HEADERS,
                200
        );
        JQLResponse resp = (JQLResponse)JSON.deserialize(b, JQLResponse.class);
        if (resp.total > 0) {
            return resp.issues[0];
        }
        return null;
    }

    public static JiraIssue getIssueInJiraByHashe3(String hash3, String jiraProjectId) {
        validateConnectionToJira();
        String jql = 'project = \''+jiraProjectId+'\' AND labels = \'h3_'+hash3+'\' AND statusCategory != \'done\' ORDER BY created ASC';
        HttpUtils.HttpURLParameters queryParams = new HttpUtils.HttpURLParameters();
        queryParams.addEncodedParameter('jql', jql);
        String b = HttpUtils.get(
                ConfigUtil.JQL_ENDPOINT + queryParams.toStringParameters('?'),
                ConfigUtil.JIRA_HEADERS,
                200
        );
        JQLResponse resp = (JQLResponse)JSON.deserialize(b, JQLResponse.class);
        if (resp.total > 0) {
            return resp.issues[0];
        }
        return null;
    }


    public static String[] sliceList(String[] arr, Integer first, Integer last) {
        String[] res = arr.clone(), temp;
        Integer size = arr.size(),
        startIndex = Math.min(size, Math.max(-1, first<0? size+first: first)),
        endIndex = Math.min(size, Math.max(-1, last<0? size+last: last-1)),
        offset = Math.max(-1, endIndex-startIndex);
        temp = new String[offset+1];
        for(Integer h = 0, i = startIndex, j = endIndex; i <= j; ) {
           temp[h++] = arr[i++];
        }
        res.clear();
        res.addAll(temp);
        return res;
    }


    public static Map<String, CreateMetaField> getIssueMetaCustomFields(List<String> projectIds, List<String> issueTypeIds) {
        Map<String, CreateMetaField> fields = new Map<String, CreateMetaField>();

        List<List<String>> listProjects = new List<List<String>>();
        Integer chunkSize = 10;
        for (Integer i = 0; i < projectIds.size(); i++){
            Integer a = i*chunkSize;
            Integer b = (i+1)*chunkSize;
            b = (b > projectIds.size()) ? projectIds.size() : b;
            String[] part = sliceList(projectIds, a, b);
            if(part.isEmpty()) break;
            listProjects.add(part);
        }

        for(List<String> chunkProjectIds : listProjects) {
            CreateMeta metaTypes = getIssueMeta(chunkProjectIds, issueTypeIds);
            for(CreateMetaProject project : metaTypes.projects) {
                for(CreateMetaIssueType issueType : project.issueTypes) {
                        for(String keyField : issueType.fields.keySet()) {
                        if(keyField.startsWith('customfield')) {
                            fields.put(keyField, issueType.fields.get(keyField));
                        }
                    }
                }
            }
        }
        return fields;
    }


    public static CreateMeta getIssueMeta(String projectId, String issueTypeId) {
        return getIssueMeta(new List<String>{projectId}, new List<String>{issueTypeId});
    }

    public static CreateMeta getIssueMeta(List<String> projectIds, List<String> issueTypeIds) {
        CreateMeta result;
        try {
            validateConnectionToJira();

            String projectIdsStr = String.join(projectIds, ',');
            String issueTypeIdsStr = String.join(issueTypeIds, ',');

            String params = '?projectIds='+projectIdsStr+'&issuetypeIds='+issueTypeIdsStr+'&expand=projects.issuetypes.fields';
            String url = ConfigUtil.GET_CREATEMETA_ENDPOINT + params;
            String b = HttpUtils.get(
                url,
                ConfigUtil.JIRA_HEADERS,
                200
            );
            result = (CreateMeta)JSON.deserialize(b, CreateMeta.class);
        }
        catch(Exception e) {
            Logger.getInstance().internalError(e, JiraService.class.getName(), 'getIssueMeta');
        }

        return result;

    }

    public static List<JiraComponent> getProjectComponents(String projectId) {

        validateConnectionToJira();

        String url = ConfigUtil.GET_PROJECT_COMMENTS_ENDPOINT.replace('projectId', projectId);

        String b = HttpUtils.get(
            url,
            ConfigUtil.JIRA_HEADERS,
            200
        );
        return (List<JiraComponent>)JSON.deserialize(b, List<JiraComponent>.class);

    }

    private static void validateConnectionToJira() {
        if (String.isBlank(ConfigUtil.JIRA_OAUTH_TOKEN) || String.isBlank(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c) ||
            String.isBlank(ConfigUtil.JIRA_SETTINGS.Jira_Username__c)
        ) {
            throw new JiraServiceException('JIRA Settings not found.');
        }
    }

    public static NewTaskCreatedResponse createTaskFromNotification(EventAction__c eventAction) {
        NewTaskCreatedResponse results = createTask(new JiraTaskInfo(eventAction));
        return results;
    }

    public static String createTaskFromLogWithAction(Id logId, Action__c rulejiraAction) {
        if(!PermissionsUtil.JiraIntegrationEnabled) return '';

        List<Log__c> logs = getLogs(logId);
        Log__c log = logs.get(0);

        // If a ticket exists for the same org and is open, do NOT create a new ticket.
        List<Log__c> sameOpenLogsByHash1 = getSameOpenLogsByHash1(log);
        if(!sameOpenLogsByHash1.isEmpty()) {
            return '';
        }

        Boolean isDefault = MonitoringUtil.ACTION_SUBTYPE_DEFAULT == rulejiraAction.Subtype__c;
        Action__c jiraAction = (isDefault) ? ConfigUtil.getDefaultJiraAction() : rulejiraAction;

        String issueKey = createTask(logs, new JiraTaskInfo(jiraAction, log));
        return issueKey;
    }

    public static List<Log__c> getLogs(Id logId) {
        /* Custom Fields Mapping */
        List<ConfigUtil.JiraFieldsMapping> fieldsMapping = ConfigUtil.JIRA_FIELDS_MAPPINGS.jira_fields_mapping;
        Set<String> logCustomFields = new Set<String>();

        for (ConfigUtil.JiraFieldsMapping fm : fieldsMapping) {
            logCustomFields.add(fm.logField);
        }
        /* end Custom Fields Mapping */

        Set<String> logFieldsToQuery = new Set<String>{
            'Id',
            ConfigUtil.nameSpacePrefix + 'Summary__c',
            ConfigUtil.nameSpacePrefix + 'Details__c',
            ConfigUtil.nameSpacePrefix + 'Bug_Tracker__c',
            ConfigUtil.nameSpacePrefix + 'Hash_1__c',
            ConfigUtil.nameSpacePrefix + 'Hash_2__c',
            ConfigUtil.nameSpacePrefix + 'Hash_3__c',
            ConfigUtil.nameSpacePrefix + 'Jira_Integration_Status__c',
            ConfigUtil.nameSpacePrefix + 'Organization_Id__c'
        };
        logFieldsToQuery.addAll(logCustomFields);

        String query = new QBuilder(Log__c.SObjectType)
            .selectFields(logFieldsToQuery)
            .add(QBuilder.condition('Id').equalsTo(logId))
            .build();
        List<Log__c> logs = Database.query(query);
        return logs;
    }

    public static String createTask(List<Log__c> logs, JiraTaskInfo jiraTaskInfo) {
        String issueKey = null;

        if(!logs.isEmpty()) {
            Log__c log = logs.get(0);
            String existingIssueKey = null;

            if(log.Bug_Tracker__c != null) {
                existingIssueKey = getIssueKeyByUrl(log.Bug_Tracker__c);
                issueKey = existingIssueKey;
                String existingIssueStatus = getIssueStatus(existingIssueKey);

                if(existingIssueStatus != 'done') {
                    PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Jira_Integration_Status__c, ConfigUtil.EXISTING_TICKET_LINKED_STATUS);
                    PermissionsUtil.performUpdateDML(new List<Log__c>{log}, Schema.sObjectType.Log__c);

                    /** Search for other Logs with Hash1 and Empty Bug_Tracker field */
                    List<Log__c> logsWithHash1 = getOtherLogsWithHash1AndEmptyBugTrackerLink(log);
                    for(Log__c l : logsWithHash1) {
                        if(String.isBlank(l.Bug_Tracker__c)) {
                            l.Bug_Tracker__c = log.Bug_Tracker__c;
                            l.Jira_Integration_Status__c = ConfigUtil.EXISTING_TICKET_LINKED_STATUS;
                        }
                    }
                    PermissionsUtil.performUpdateDML(logsWithHash1, Schema.sObjectType.Log__c);
                    return issueKey;
                }
            }
            try {
                CreateMeta issueCreateMeta = JiraService.getIssueMeta(jiraTaskInfo.projectJiraId, jiraTaskInfo.jiraIssueTypeId);
                if(issueCreateMeta == null || issueCreateMeta.projects == null || issueCreateMeta.projects.isEmpty()) {
                    throw new JiraServiceException('Unable to create a jira ticket for project ' + jiraTaskInfo.projectJiraId + '. Please double check Jira integration settings.');
                }
                Set<String> projectCustomFields = new Set<String>();
                for (CreateMetaField f : issueCreateMeta.projects[0].issuetypes[0].fields.values()) {
                    projectCustomFields.add(f.key);
                }
                jiraTaskInfo.customFields = new Map<String, String>();
                for (ConfigUtil.JiraFieldsMapping fm : ConfigUtil.JIRA_FIELDS_MAPPINGS.jira_fields_mapping) {
                    if(projectCustomFields.contains(fm.jiraField)) {
                        try {
                            jiraTaskInfo.customFields.put(fm.jiraField, String.valueOf(log.get(fm.logField)));
                        }
                        catch(Exception e) {}
                    }
                }

                jiraTaskInfo.logId = log.Id;
                jiraTaskInfo.hash2 = log.Hash_2__c;
                jiraTaskInfo.hash3 = log.Hash_3__c;
                NewTaskCreatedResponse results = createTask(jiraTaskInfo);
                issueKey = results.key;

                try {
                    // When creating a ticket,
                    // if an open ticket for same hash1 under a different org already exists in JIRA,
                    // still create a new ticket and link the open ticket to it.
                    List<Log__c> relatedOpenLogsByHash1 = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? new List<Log__c>() : [
                        SELECT Id, Bug_Tracker__c
                        FROM Log__c
                        WHERE Id != :log.Hash_1__c
                            AND Hash_1__c = :log.Hash_1__c
                            AND Organization_Id__c != :log.Organization_Id__c
                            AND Resolved_On__c = null
                            AND Bug_Tracker__c != null
                        LIMIT 1
                    ];

                    // If a ticket exists for the same org and is closed,
                    // create a new ticket and relate to the closed one, just like our logic used to work before.
                    List<Log__c> relatedClosedLogsByHash1 = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? new List<Log__c>() : [
                        SELECT Id, Bug_Tracker__c
                        FROM Log__c
                        WHERE Id != :log.Hash_1__c
                            AND Hash_1__c = :log.Hash_1__c
                            AND Organization_Id__c = :log.Organization_Id__c
                            AND Resolved_On__c != null
                            AND Bug_Tracker__c != null
                        LIMIT 1
                    ];
                    if(!relatedClosedLogsByHash1.isEmpty()) {
                        String relatedClosedTicketKey = getIssueKeyByUrl(relatedClosedLogsByHash1.get(0).Bug_Tracker__c);
                        linkIssuesAsDuplicates(issueKey, relatedClosedTicketKey);
                    }
                    if(!relatedOpenLogsByHash1.isEmpty()) {
                        String relatedOpenTicketKey = getIssueKeyByUrl(relatedOpenLogsByHash1.get(0).Bug_Tracker__c);
                        linkIssuesAsDuplicates(issueKey, relatedOpenTicketKey);
                    }
                }
                catch(Exception e) {
                    Logger.getInstance().internalError(e, log.Id, true, JiraService.class.getName(), 'createTask');
                }

                try {
                    linkExistingJiraTasks(results, log, jiraTaskInfo.projectJiraId);
                }
                catch(Exception e) {
                    Logger.getInstance().internalError(e, log.Id, true, JiraService.class.getName(), 'createTask.linkExistingJiraTasks');
                }

                saveJiraInformationToLog(new List<Log__c>{log}, results);

            }
            catch(Exception e) {
                Logger.getInstance().internalError(e, log.Id, true, JiraService.class.getName(), 'createTask.saveJiraInformationToLog');
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Bug_Tracker__c, null);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Jira_Integration_Status__c, ConfigUtil.TICKET_CREATE_ERROR_STATUS);
                PermissionsUtil.performUpdateDML(new List<Log__c>{log}, Schema.sObjectType.Log__c);
            }
        }
        return issueKey;
    }

    public static List<Log__c> getSameOpenLogsByHash1(Log__c log) {
        List<Log__c> someOpenLogsByHash1 = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? new List<Log__c>() : [
            SELECT Id, Bug_Tracker__c, Jira_Integration_Status__c, Hash_1__c
            FROM Log__c
            WHERE Id != :log.Id
                AND Hash_1__c = :log.Hash_1__c
                AND Organization_Id__c = :log.Organization_Id__c
                AND Resolved_On__c = null
                AND Bug_Tracker__c != null
            LIMIT 1
        ];
        return someOpenLogsByHash1;
    }

    public static List<Log__c> getOtherLogsWithHash1AndEmptyBugTrackerLink(Log__c log) {
        /** Search for other Logs with Hash1 and Empty Bug_Tracker field */
        String query = new QBuilder(Log__c.SObjectType)
            .selectFields(new Set<String>{'Id', 'Bug_Tracker__c', 'Jira_Integration_Status__c'})
            .add(QBuilder.condition('Hash_1__c').EqualsTo(log.Hash_1__c))
            .add(QBuilder.condition('Hash_1__c').notEqualsTo(null))
            .add(QBuilder.condition('Bug_Tracker__c').EqualsTo(null))
            .add((ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? QBuilder.condition('Organization_Id__c').EqualsTo(log.Organization_Id__c) : null)
            .add(QBuilder.condition('Id').notEqualsTo(log.Id))
            .build();
        List<Log__c> logs = Database.query(query);
        return logs;
    }

    public static List<Log__c> getOtherLogsWithHash1AndNotEmptyBugTrackerLink(Log__c log) {
        /** Search for other Logs with Hash1 and not Empty Bug_Tracker field */
        String query = new QBuilder(Log__c.SObjectType)
            .selectFields(new Set<String>{'Id', 'Bug_Tracker__c', 'Jira_Integration_Status__c'})
            .add(QBuilder.condition('Hash_1__c').EqualsTo(log.Hash_1__c))
            .add(QBuilder.condition('Hash_1__c').notEqualsTo(null))
            .add(QBuilder.condition('Bug_Tracker__c').notEqualsTo(null))
            .add((ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? QBuilder.condition('Organization_Id__c').EqualsTo(log.Organization_Id__c) : null)
            .add(QBuilder.condition('Id').notEqualsTo(log.Id))
            .build();
        List<Log__c> logs = Database.query(query);
        return logs;
    }

    public static void linkExistingJiraTasks(NewTaskCreatedResponse results, Log__c log, String jiraProjectId) {
        /* Search for first Jira Issue linked by Hash1 */
        List<Log__c> firstLogByHash1Available = getOtherLogsWithHash1AndNotEmptyBugTrackerLink(log);

        Log__c firstLogByHash1 = firstLogByHash1Available.size() > 0 ? firstLogByHash1Available[0] : log;
        if (firstLogByHash1.Bug_Tracker__c != null) {
            String existingIssueKey = getIssueKeyByUrl(firstLogByHash1.Bug_Tracker__c);
            linkIssuesAsDuplicates(results.key, existingIssueKey);
        }
        JiraIssue existingIssueWithHash2 = getIssueInJiraByHashe2(log.Hash_2__c, jiraProjectId);
        if (ConfigUtil.JIRA_SETTINGS.Auto_Relate_Tickets_With_Similar_Errors__c &&
            existingIssueWithHash2 != null &&
            results.key != existingIssueWithHash2.key
        ){
            linkIssuesAsDuplicates(results.key, existingIssueWithHash2.key);
        }
        JiraIssue existingIssueWithHash3 = getIssueInJiraByHashe3(log.Hash_3__c, jiraProjectId);
        if (ConfigUtil.JIRA_SETTINGS.Auto_Relate_Tickets_With_Similar_Errors__c &&
            existingIssueWithHash3 != null &&
            (existingIssueWithHash2 == null || existingIssueWithHash2.key != existingIssueWithHash3.key) &&
            results.key != existingIssueWithHash3.key
        ){
            linkIssuesAsDuplicates(results.key, existingIssueWithHash3.key);
        }
    }

    public static Log__c saveJiraInformationToLog(List<Log__c> logs, NewTaskCreatedResponse results) {
        Log__c log = logs.get(0);
        String taskUrl = ConfigUtil.JIRA_TASK_URL + results.key;
        List<Log__c> logsWithHash1 = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? [
            SELECT Id, Bug_Tracker__c, Jira_Integration_Status__c
            FROM Log__c
            WHERE ( Hash_1__c = :log.Hash_1__c
                AND Hash_1__c != null
                AND Bug_Tracker__c = null
            ) OR Id = :log.Id
        ] : [
            SELECT Id, Bug_Tracker__c, Jira_Integration_Status__c
            FROM Log__c
            WHERE ( Hash_1__c = :log.Hash_1__c
                    AND Organization_Id__c = :log.Organization_Id__c
                    AND Hash_1__c != null
                    AND Bug_Tracker__c = null
            ) OR Id = :log.Id
        ];
        for (Log__c l : logsWithHash1) {
            if (String.isBlank(l.Bug_Tracker__c)) {
                l.Bug_Tracker__c = taskUrl;
                l.Jira_Integration_Status__c = ConfigUtil.EXISTING_TICKET_LINKED_STATUS;
            }
        }
        PermissionsUtil.performUpdateDML(logsWithHash1, Schema.sObjectType.Log__c);

        PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Bug_Tracker__c, taskUrl);
        PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Jira_Integration_Status__c, ConfigUtil.NEW_TICKET_CREATED_STATUS);
        PermissionsUtil.performUpdateDML(new List<Log__c>{log}, Schema.sObjectType.Log__c);
        return log;
    }

    public class JiraTaskInfo {
        public String summary;
        public String details;
        public String assignee;
        public String labels;
        public List<String> componentIds;
        public String epicId;
        public String hash2;
        public String hash3;
        public Map<String, String> customFields;
        public Id logId;
        public String projectJiraId;
        public String jiraIssueTypeId;
        public String jiraPriority;

        public JiraTaskInfo() {}

        public JiraTaskInfo(EventAction__c eventAction) {
            this.summary =  NotificationBatch.renderMergeFields(eventAction.Action__r.Subject__c, eventAction);
            this.details = this.summary + '\n\n' + NotificationBatch.renderMergeFields(eventAction.Action__r.Body__c, eventAction);
            this.summary = this.summary.abbreviate(255);
            this.assignee = eventAction.Action__r.JIRAAssignee_Id__c;
            this.labels = eventAction.Action__r.JIRALabels__c;
            this.componentIds = String.isNotBlank(eventAction.Action__r.JIRAComponents__c) ? eventAction.Action__r.JIRAComponents__c.split(',') : new List<String>();
            this.epicId = eventAction.Action__r.JIRAEpic__c;
            this.projectJiraId = eventAction.Action__r.JIRAProject__c;
            this.jiraIssueTypeId = eventAction.Action__r.JIRAIssueType__c;
            this.jiraPriority = eventAction.Action__r.JIRAPriority__c;
        }

        public JiraTaskInfo(Action__c jiraAction, Log__c log) {
            this.summary = (String.isBlank(jiraAction.Subject__c))
                ? log.Summary__c
                : NotificationBatch.renderMergeFields(jiraAction.Subject__c, log.Id);
            this.details = this.summary + '\n\n' + ((String.isBlank(jiraAction.Body__c))
                ? URL.getSalesforceBaseUrl().toExternalForm() + '/' + log.Id + '\n\n' + log.Details__c
                : NotificationBatch.renderMergeFields(jiraAction.Body__c, log.Id));
            this.summary = this.summary.abbreviate(255);

            this.assignee = jiraAction.JIRAAssignee_Id__c;
            this.labels = jiraAction.JIRALabels__c;
            this.componentIds = String.isNotBlank(jiraAction.JIRAComponents__c) ? jiraAction.JIRAComponents__c.split(',') : new List<String>();
            this.epicId = jiraAction.JIRAEpic__c;
            this.projectJiraId = jiraAction.JIRAProject__c;
            this.jiraIssueTypeId = jiraAction.JIRAIssueType__c;
            this.jiraPriority = jiraAction.JIRAPriority__c;
        }
    }

    public static NewTaskCreatedResponse createTask(JiraTaskInfo jiraTaskInfo) {

        validateConnectionToJira();
        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
        jiraTaskInfo.projectJiraId = jiraTaskInfo.projectJiraId == null ? defaultJiraAction.JIRAProject__c : jiraTaskInfo.projectJiraId;
        jiraTaskInfo.jiraIssueTypeId = jiraTaskInfo.jiraIssueTypeId == null ? defaultJiraAction.JIRAIssueType__c : jiraTaskInfo.jiraIssueTypeId;
        Integer detailsFieldLength = Integer.valueOf(ConfigUtil.JIRA_SETTINGS.Jira_Details_Field_Length__c > 0 ? ConfigUtil.JIRA_SETTINGS.Jira_Details_Field_Length__c : 30000);


        jiraTaskInfo.details = jiraTaskInfo.details.abbreviate(detailsFieldLength);

        Map<String, Object> bodyObject = new Map<String, Object>{
            'fields' => new Map<String, Object>{
                'project' => new Map<String, Object>{
                    'id' => jiraTaskInfo.projectJiraId
                },
                'issuetype' => new Map<String, Object>{
                    'id' => jiraTaskInfo.jiraIssueTypeId
                },
                'summary' => jiraTaskInfo.summary,
                'description' => jiraTaskInfo.details
            }
        };

        if (String.isNotBlank(jiraTaskInfo.jiraPriority)) {
            ((Map<String, Object>)(bodyObject.get('fields'))).put(
                'priority', new Map<String, Object>{
                    'id' => jiraTaskInfo.jiraPriority
                }
            );
        }

        CreateMeta issueCreateMeta = JiraService.getIssueMeta(jiraTaskInfo.projectJiraId, jiraTaskInfo.jiraIssueTypeId);

        if (String.isNotBlank(jiraTaskInfo.assignee)) {
            String assigneeKey = (isCloudJiraInstance() || isJiraHashId(jiraTaskInfo.assignee)) ? 'id' : 'name';
            ((Map<String, Object>)(bodyObject.get('fields'))).put(
                'assignee', new Map<String, Object>{
                    assigneeKey => jiraTaskInfo.assignee
                }
            );
        }
        if (ConfigUtil.JIRA_SETTINGS.Auto_Generate_Similarity_Labels__c) {
            List<String> labelsWithHashesList = new List<String>();
            if (String.isNotBlank(jiraTaskInfo.labels)) {
                labelsWithHashesList.add(jiraTaskInfo.labels);
            }
            if (String.isNotBlank(jiraTaskInfo.hash2)) {
                labelsWithHashesList.add('h2_' + jiraTaskInfo.hash2);
            }
            if (String.isNotBlank(jiraTaskInfo.hash3)) {
                labelsWithHashesList.add('h3_' + jiraTaskInfo.hash3);
            }
            jiraTaskInfo.labels = String.join(labelsWithHashesList, ',');
        }
        if (String.isNotBlank(jiraTaskInfo.labels)) {
            List<String> labelsList = jiraTaskInfo.labels.split(',');
            for (Integer i=0; i<labelsList.size(); i++) {
                labelsList[i] = labelsList[i].trim();
            }
            ((Map<String, Object>)(bodyObject.get('fields'))).put(
                'labels', labelsList
            );
        }

        if (String.isNotBlank(jiraTaskInfo.epicId)) {
            CreateMetaField epicLinkField;
            for (CreateMetaField f : issueCreateMeta.projects[0].issuetypes[0].fields.values()) {
                if (f.name == 'Epic Link' && (f.fieldId != null || f.key != null)) {
                    epicLinkField = f;
                    break;
                }
            }
            if (epicLinkField != null) {
                ((Map<String, Object>)(bodyObject.get('fields'))).put(
                    (epicLinkField.key != null ? epicLinkField.key : epicLinkField.fieldId), jiraTaskInfo.epicId
                );
            }
        }
        if (jiraTaskInfo.componentIds != null && jiraTaskInfo.componentIds.size() > 0) {
            List<Map<String, Object>> componentsObjs = new List<Map<String, Object>>();
            for (String cId : jiraTaskInfo.componentIds) {
                componentsObjs.add(
                    new Map<String, Object>{
                        'id' => cId
                    }
                );
            }
            ((Map<String, Object>)(bodyObject.get('fields'))).put(
                'components', componentsObjs
            );
        }
        if (jiraTaskInfo.customFields != null) {
            for (String key : jiraTaskInfo.customFields.keySet()) {
                ((Map<String, Object>)(bodyObject.get('fields'))).put(key, jiraTaskInfo.customFields.get(key));
            }
        }
        String b = HttpUtils.post(
            ConfigUtil.CREATE_ISSUE_ENDPOINT,
            JSON.serialize(bodyObject),
            ConfigUtil.JIRA_HEADERS,
            201
        );
        NewTaskCreatedResponse result = (NewTaskCreatedResponse)JSON.deserialize(b, NewTaskCreatedResponse.class);
        if (jiraTaskInfo.logId != null) {
            // Add information for Pharos Jira Plugin
            addJiraTaskProperties(result, jiraTaskInfo.logId);
        }
        return result;
    }

    public static final Pattern JIRA_HASH_PATTERN = Pattern.compile('^[a-zA-Z0-9]{6}:[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}$');
    public static Boolean isJiraHashId(String assignee){
        Boolean result = false;
        Matcher m = JIRA_HASH_PATTERN.matcher(assignee);
        result = m.find();
        return result;
    }

    public static Boolean isCloudJiraInstance() {
        Boolean result = String.isNotBlank(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c)
            && ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c.startsWith('https://')
            && ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c.endsWith('.atlassian.net');
        return result;
    }

    public static void addJiraTaskProperties(NewTaskCreatedResponse issue, Id logId) {
        Map<String, Object> bodyObject = new Map<String, Object>{
            'id' => logId,
            'instance' => ConfigUtil.BASE_URL,
            'org_id' => UserInfo.getOrganizationId(),
            'is_sandbox' => ConfigUtil.currentOrgIsSandbox,
            'is_enabled' => true
        };
        String url = ConfigUtil.CREATE_JIRA_PROPERTY_PHAROS_LOG_ENDPOINT.replace('issueKey', issue.key);
        String b = HttpUtils.put(
            url,
            JSON.serialize(bodyObject),
            ConfigUtil.JIRA_HEADERS,
            201
        );
    }

    /* inwardIssueKey duplicates outwardIssueKey */
    public static void linkIssuesAsDuplicates(String inwardIssueKey, String outwardIssueKey) {
        Map<String, Object> bodyObject = new Map<String, Object>{
            'outwardIssue' => new Map<String, Object>{
                'key' => outwardIssueKey
            },
            'inwardIssue' => new Map<String, Object>{
                'key' => inwardIssueKey
            },
            'type' => new Map<String, Object>{
                'name' => 'Relates'
            }
        };
        String b = HttpUtils.post(
            ConfigUtil.CREATE_ISSUE_LINK_ENDPOINT,
            JSON.serialize(bodyObject),
            ConfigUtil.JIRA_HEADERS,
            201
        );
    }

    public static String getIssueStatus(String taskKey) {
        String s1 = getIssueDetailsByKey(taskKey);
        try {
            JiraIssue issueWithStatus = (JiraIssue)JSON.deserialize(s1, JiraIssue.class);
            return issueWithStatus.fields.status.statusCategory.key;
        } catch (Exception e) {
            throw new JiraServiceException('Invalid Issue Object: ' + String.valueOf(s1));
        }
    }

    public static String getIssueKeyByUrl(String taskUrl) {
        String taskKey = null;
        try {
            /* taskUrl example: https://goldenratio.atlassian.net/browse/PTD-2 */
            taskKey = taskUrl.split('/browse/')[1];
        } catch(Exception e) {
            throw new JiraServiceException('Invalid Jira Task URL: ' + String.valueOf(taskUrl));
        }
        return taskKey;
    }

    public static String getIssueDetailsByKey(String taskKey) {
        validateConnectionToJira();
        String expand = '';
        if(ConfigUtil.API_VERSION == '2') {
            expand = '?expand=renderedFields';
        }
        String b = HttpUtils.get(
            ConfigUtil.GET_ISSUE_DETAILS_ENDPOINT + taskKey + expand,
            ConfigUtil.JIRA_HEADERS,
            200
        );
        return b;
    }

    public static Map<String, DateTime> getResolutionDatetimeByTaskKey(List<String> taskKeys) {
        Map<String, DateTime> result = new Map<String, DateTime>();

        String bulkTaskResponse = getBulkResolutionTasks(taskKeys);
        if(String.isNotBlank(bulkTaskResponse)) {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(bulkTaskResponse);
            List<Object> issues = (List<Object>)data.get('issues');

            for(Object issueObject : issues) {
                Map<String, Object> issue = (Map<String, Object>)issueObject;
                String key = (String)issue.get('key');

                Map<String, Object> fields = (Map<String, Object>)issue.get('fields');
                if(fields.containsKey('resolutiondate')) {
                    String dateTimeString = String.valueOf(fields.get('resolutiondate'));
                    DateTime resolutionDatetime = parseJiraDateTime(dateTimeString);

                    result.put(key, resolutionDatetime);
                }
            }
        }
        return result;
    }

    public static String getBulkResolutionTasks(List<String> taskKeys) {
        String b = null;
        if(!taskKeys.isEmpty()) {
            // /rest/api/2/search?jql=KEY%20IN%20(key1,key2,...,keyN)&fields=status&maxResults=100)
            try {
                String jql = 'KEY IN (' + String.join(taskKeys, ',') + ')';
                HttpUtils.HttpURLParameters queryParams = new HttpUtils.HttpURLParameters();
                queryParams.addEncodedParameterWithFixedWhitespace('jql', jql);
                queryParams.addParameter('fields', 'resolutiondate');
                queryParams.addParameter('maxResults', '100');
                queryParams.addParameter('validateQuery', 'false');
                b = HttpUtils.get(
                        ConfigUtil.JQL_ENDPOINT + queryParams.toStringParameters('?'),
                        ConfigUtil.JIRA_HEADERS,
                        200
                );
            }
            catch(Exception e) {
                Logger.getInstance().internalError(e, null, true, JiraService.class.getName(), 'getBulkResolutionTasks');
            }
        }
        return b;
    }

    public static List<String> getJiraKeys(List<Log__c> logs) {
        Set<String> keys = new Set<String>();
        for(Log__c log : logs) {
            String taskKey = getLogJiraKey(log);
            if(String.isNotBlank(taskKey)) {
                keys.add(taskKey);
            }
        }
        return new List<String>(keys);
    }

    public static String getLogJiraKey(Log__c log) {
        String taskKey = null;
        if(String.isNotBlank(log.Bug_Tracker__c)) {
            taskKey = log.Bug_Tracker__c.split('/browse/')[1];
        }
        return taskKey;
    }

    // '2020-04-24T10:41:33.239-0700'
    public static final Pattern JIRA_DATE_TIME_PATTERN = Pattern.compile('(?i)(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2}).(\\d{3})([-+])(\\d{4})');

    public static DateTime parseJiraDateTime(String dateTimeString) {
        DateTime result = null;

        try {
            Pattern dt = JIRA_DATE_TIME_PATTERN;
            Matcher m = dt.matcher(dateTimeString);
            if (m.find()) {
                Integer year = Integer.valueOf(m.group(1));
                Integer month = Integer.valueOf(m.group(2));
                Integer day = Integer.valueOf(m.group(3));
                Integer hour = Integer.valueOf(m.group(4));
                Integer minute = Integer.valueOf(m.group(5));
                Integer second = Integer.valueOf(m.group(6));
                Integer mills = Integer.valueOf(m.group(7));
                String timeZone = m.group(8);
                String timeZoneHour = m.group(9).substring(0, 2);
                String timeZoneMinute = m.group(9).substring(2, 4);

                result = Datetime.newInstanceGmt(year, month, day, hour, minute, second);
                if ('-' == timeZone) {
                    result = result.addHours(-Integer.valueOf(timeZoneHour));
                    result = result.addMinutes(-Integer.valueOf(timeZoneMinute));
                } else if ('+' == timeZone) {
                    result = result.addHours(Integer.valueOf(timeZoneHour));
                    result = result.addMinutes(Integer.valueOf(timeZoneMinute));
                }
            }
        }
        catch (Exception e) {}
        return result;
    }


    public class NewTaskCreatedResponse {
        public String id;
        public String key;
        public String self;
    }

    public class Epic {
        public String id;
        public String key;
        public EpicFields fields;
    }

    public class EpicFields {
        public String summary;
    }

    public class JiraProjectMetaList {
        public List<JiraProjectMeta> projects;
    }

    public class JiraProjectMeta {
        public String id;
        public String key;
        public String name;
        public List<JiraIssueType> issueTypes;
    }

    public class JiraIssueType {
        public String id;
        public String name;
        public String untranslatedName;
    }

    public class JiraUser {
        public String accountId;
        public String key;
        public String name;
        public String emailAddress;
        public String displayName;
        public Boolean active;
    }

    public class JiraComponent {
        public String id;
        public String name;
        public String description;
    }

    public class CreateMeta {
        public List<CreateMetaProject> projects;
    }

    public class CreateMetaProject {
        public String id;
        public String key;
        public List<CreateMetaIssueType> issuetypes;
    }

    public class CreateMetaIssueType {
        public String id;
        public String name;
        public Map<String, CreateMetaField> fields;
    }

    public class CreateMetaField {
        public Boolean required;
        public String name;
        // api version 3
        public String key;
        // api version 2
        public String fieldId;
    }

    public class JQLResponse {
        public Integer total;
        public List<JiraIssue> issues;
    }

    public class JiraIssue {
        public string id;
        public string key;
        public JiraIssueFields fields;
    }

    public class JiraIssueFields {
        public JiraIssueStatus status;
    }

    public class JiraIssueStatus {
        public String id;
        public String name;
        public JiraIssueStatusCategory statusCategory;
    }

    public class JiraIssueStatusCategory {
        public String id;
        public String key;
    }

    public class JiraPriority {
        public String id;
        public String self;
        public String statusColor;
        public String description;
        public String iconUrl;
        public String name;
    }


    public class JiraServiceException extends Exception {}

}