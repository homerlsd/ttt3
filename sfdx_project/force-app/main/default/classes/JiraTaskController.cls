public with sharing class JiraTaskController {

    public Boolean jiraSettingAvailable { get; set; }
    public Log__c log { get; set; }
    public String errorMessage { get; set; }
    public Boolean redirect { get; set; }
    public String taskDescription { get; set; }
    public String taskLabels { get; set; }
    public String taskAssignee { get; set; }
    public String taskAssigneeId { get; set; }
    public List<SelectOption> jiraUsersOptions { get; set; }
    public List<String> taskComponents { get; set; }
    public List<SelectOption> jiraComponentsOptions { get; set; }
    public String epicId { get; set; }
    public List<SelectOption> epicsOptions { get; set; }
    public String projectId { get; set; }
    public String taskProject { get; set; }
    public List<SelectOption> jiraProjectOptions { get; set; }
    public String issueTypeId { get; set; }
    public String issueType { get; set; }
    public List<SelectOption> issueTypeOptions { get; set; }

    public JiraTaskController(ApexPages.StandardController stdController) {
        this.log = [
            SELECT Id, Name, Summary__c, Details__c, Bug_Tracker__c, Hash_1__c, Hash_2__c, Hash_3__c
            FROM Log__c
            WHERE Id = :stdController.getId()
        ];
        this.taskDescription = Url.getSalesforceBaseUrl().toExternalForm() + '/' + log.Id + '\n\n' + this.log.Details__c;
        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
        this.taskLabels = defaultJiraAction.JIRALabels__c;
        this.taskAssignee = defaultJiraAction.JIRAAssignee__c;
        this.taskAssigneeId = defaultJiraAction.JIRAAssignee_Id__c;
        this.epicId = defaultJiraAction.JIRAEpic__c;
        this.taskComponents = String.isNotBlank(defaultJiraAction.JIRAComponents__c) ? defaultJiraAction.JIRAComponents__c.split(',') : new List<String>();
        this.projectId = defaultJiraAction.JIRAProject__c;
        this.issueTypeId = defaultJiraAction.JIRAIssueType__c;
        if (this.log.Bug_Tracker__c == null) {
            errorMessage = ConfigUtil.JIRA_TASK_NOT_FOUND_MESSAGE;
        }
        jiraSettingAvailable = String.isNotBlank(ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c) && String.isNotBlank(ConfigUtil.JIRA_SETTINGS.Jira_Username__c) && String.isNotBlank(ConfigUtil.JIRA_OAUTH_TOKEN);
        if (!jiraSettingAvailable) {
            errorMessage = ConfigUtil.JIRA_SETTINGS_NOT_FOUND_MESSAGE;
        } else {
            getProjects();
            if (String.isNotBlank(this.projectId)) {
                getIssueType();
                getProjectAssignableUsers();
                getEpics();
                getProjectComponents();
            }
        }
        redirect = false;
    }

    public PageReference init() {
        if (String.isNotBlank(log.Bug_Tracker__c)) {
            PageReference pageRef = new PageReference(log.Bug_Tracker__c);
            return pageRef;
        }
        return null;
    }

    public PageReference refresh() {
        issueType = null;
        taskAssigneeId = null;
        epicId = null;
        taskComponents = new List<String>();
        if (String.isNotBlank(this.taskProject)) {
            getIssueType();
            getProjectAssignableUsers();
            getEpics();
            getProjectComponents();
        }
        return null;
    }

    public PageReference createNewJiraTask() {
        try {
            List<Log__c> logs = JiraService.getLogs(this.log.Id);
            Log__c log = logs.get(0);
            JiraService.JiraTaskInfo jti = new JiraService.JiraTaskInfo();
            jti.summary = log.Summary__c;
            jti.details = this.taskDescription;
            jti.assignee = this.taskAssigneeId;
            jti.labels = this.taskLabels;
            jti.componentIds = this.taskComponents;
            jti.epicId = this.epicId;
            jti.projectJiraId = this.taskProject;
            jti.jiraIssueTypeId = this.issueType;
            JiraService.createTask(logs, jti);
            this.log = [
                    SELECT Id, Name, Summary__c, Details__c, Bug_Tracker__c, Hash_1__c, Hash_2__c, Hash_3__c
                    FROM Log__c
                    WHERE Id = :log.Id
            ];
            errorMessage = null;
            this.redirect = true;
            return null;
        } catch(Exception e) {
            errorMessage = 'ERROR: ' + e.getMessage();
            Logger.getInstance().internalError(e, this.log.Id, true, JiraTaskController.class.getName(), 'createNewJiraTask');
        }
        return null;
    }

    public void getProjects() {
        jiraProjectOptions = new List<SelectOption>();
        jiraProjectOptions.add(new SelectOption('', '--select--'));
        for (JiraService.JiraProjectMeta jiraProjectMeta : JiraService.getProjects()) {
            jiraProjectOptions.add(new SelectOption(jiraProjectMeta.id, jiraProjectMeta.name));
            if (jiraProjectMeta.id == projectId) {
                taskProject = jiraProjectMeta.id;
            }
        }
    }

    public void getIssueType() {
        issueTypeOptions = new List<SelectOption>();
        issueTypeOptions.add(new SelectOption('', '--select--'));
        for (JiraService.JiraProjectMeta jiraProjectMeta : JiraService.getProjects()) {
            if (jiraProjectMeta.id == taskProject) {
                for (JiraService.JiraIssueType jiraIssueType : jiraProjectMeta.issueTypes) {
                    issueTypeOptions.add(new SelectOption(jiraIssueType.id, jiraIssueType.name));
                    if (jiraIssueType.id == issueTypeId) {
                        issueType = jiraIssueType.id;
                    }
                }
            }
        }
    }

    public void getProjectAssignableUsers() {
        jiraUsersOptions = new List<SelectOption>();
        jiraUsersOptions.add(new SelectOption('','Unassigned'));
        for (JiraService.JiraUser jiraUser : JiraService.getProjectAssignableUsers(taskProject)) {
            // u.name for Jira Server platform
            // u.accountId for Jira Cloud
            String assigneeId = (jiraUser.accountId == null) ? jiraUser.name : jiraUser.accountId;
            jiraUsersOptions.add(new SelectOption(assigneeId, jiraUser.displayName));
        }
    }

    public void getEpics() {
        epicsOptions = new List<SelectOption>();
        epicsOptions.add(new SelectOption('','--none--'));
        for (JiraService.Epic epic : JiraService.getEpics(taskProject)) {
            epicsOptions.add(new SelectOption(epic.key, epic.fields.summary + ' (' + epic.key + ')'));
        }
    }

    public void getProjectComponents() {
        jiraComponentsOptions = new List<SelectOption>();
        for (JiraService.JiraComponent jiraComponent : JiraService.getProjectComponents(taskProject)) {
            jiraComponentsOptions.add(new SelectOption(jiraComponent.id, jiraComponent.name));
        }
    }

}