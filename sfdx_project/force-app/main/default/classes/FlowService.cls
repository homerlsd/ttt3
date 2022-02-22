public with sharing class FlowService {

	public static final Pattern PROCESS_BUILDER_MARKUP_FIXES_PATTERN = Pattern.compile('<br>|<hr>|</body>|&#39;|<a.*?>|</a>|<(\\/?)\\w+:(\\w+\\/?) ?(\\w+:\\w+.*)?>');
	public static final String HTML_TAG_PARAGRAPH = 'p';
	public static final String HTML_TAG_SPAN = 'span';
	public static final String PB_STACK_TRACE_EOL = '\n';
	public static final String PB_CURRENT_SUPPORTED_API_VERSION = '50.0';
	public static final String PB_STACK_NON_ALPHANUMERIC_REGEX = '[^a-zA-Z]';

	public static List<String> getFlowExecutionPath(String htmlStackTrace) {
		List<String> result = new List<String>();
		Dom.XmlNode[] rootElements = getRootElementsFromHtml(htmlStackTrace);
		Set<String> skipNodes = new Set<String>{'Result','Inputs:','Outputs:'};

		for(Dom.XmlNode xmlNode : rootElements) {
			Dom.XmlNodeType nodeType = xmlNode.getNodeType();
			String blockName;
			String childsBlockLines;
			switch on nodeType {
				when TEXT {}
				when ELEMENT {
					Dom.XmlNode[] elementNodes = xmlNode.getChildren();
					for(Dom.XmlNode childXmlNode : elementNodes) {
						Dom.XmlNodeType childNodeType = childXmlNode.getNodeType();
						switch on childNodeType {
							when ELEMENT {
								if(childXmlNode.getName() == HTML_TAG_SPAN) {
									blockName = childXmlNode.getText();
								}
							}
							when TEXT {
								if(blockName != null) {
									childsBlockLines = childXmlNode.getText();
									List<String> lines = childsBlockLines.split(PB_STACK_TRACE_EOL);
									String actionAPIName = lines.get(0) != null ? lines.get(0) : '';
									if(!skipNodes.contains(blockName) && !skipNodes.contains(actionAPIName)) {
										result.add(blockName + actionAPIName.trim());
									}
									blockName = null;
								}
							}
						}
					}
				}
			}
		}
		return result;
	}

	public static Dom.XmlNode[] getRootElementsFromHtml(String htmlStackTrace) {
		// markup fixes
		Matcher m = PROCESS_BUILDER_MARKUP_FIXES_PATTERN.matcher(htmlStackTrace);
		htmlStackTrace = m.replaceAll('');

		Dom.Document errorDoc = new Dom.Document();
		errorDoc.load(htmlStackTrace);

		Dom.XmlNode root = errorDoc.getRootElement();
		Dom.XmlNode[] rootElements = root.getChildren();
		return rootElements;
	}

	// Process Builder Parser
	public static ProcessBuilder parseProcessBuilderStackTrace(String htmlStackTrace) {
		ProcessBuilder result = null;

		Dom.XmlNode[] rootElements = getRootElementsFromHtml(htmlStackTrace);

		String processBuilderAPIName = getProcessBuilderApiName(rootElements);

		if(String.isNotBlank(processBuilderAPIName)) {
			ProcessBuilderHelper helper = new ProcessBuilderHelper();
			result = getProcessBuilder(processBuilderAPIName, helper);
			helper.replaceIdsByNames(result);

			String firstNodeError;
			String blockName;
			String childsBlockLines;

			String parentDecisionIndex = null;
			String parentActionAPIName = null;
			String parentBlockName = null;

			for(Dom.XmlNode xmlNode : rootElements) {
				Dom.XmlNodeType nodeType = xmlNode.getNodeType();

				switch on nodeType {
					when TEXT {}
					when ELEMENT {
						if(xmlNode.getName() == HTML_TAG_PARAGRAPH && firstNodeError == null) {
							firstNodeError = xmlNode.getText();
						}
						Dom.XmlNode[] elementNodes = xmlNode.getChildren();
						for(Dom.XmlNode childXmlNode : elementNodes) {
							Dom.XmlNodeType childNodeType = childXmlNode.getNodeType();
							switch on childNodeType {
								when ELEMENT {
									if(childXmlNode.getName() == HTML_TAG_SPAN) {
										blockName = childXmlNode.getText();
									}
								}
								when TEXT {
									if(blockName != null) {
										childsBlockLines = childXmlNode.getText();
										List<String> lines = childsBlockLines.split(PB_STACK_TRACE_EOL);
										Boolean isAction = blockName.replaceAll(PB_STACK_NON_ALPHANUMERIC_REGEX, '').isAllUpperCase();

										Map<String, Object> myVariable = getContextVariables(lines, (Map<String, Object>)result.context.get(PB_ST_COMMON_VAR_NAME));
										result.context.put(PB_ST_COMMON_VAR_NAME, myVariable);

										if(blockName == PB_ST_FLOW_DETAILS) {
											result.context.put(PB_ST_VAR_FLOW_API_NAME_NAME, getLineValue(lines, PB_ST_VAR_FLOW_API_NAME_LABEL));
											result.context.put(PB_ST_VAR_TYPE_NAME, getLineValue(lines, PB_ST_VAR_TYPE_LABEL));
											result.context.put(PB_ST_VAR_VERSION_NAME, getLineValue(lines, PB_ST_VAR_VERSION_LABEL));
											result.context.put(PB_ST_VAR_STATUS_NAME, getLineValue(lines, PB_ST_VAR_STATUS_LABEL));
											result.context.put(PB_ST_VAR_ORG_NAME, getLineValue(lines, PB_ST_VAR_ORG_LABEL));
										}
										else if(blockName == PB_ST_FLOW_INTERVIEW_DETAILS) {
											result.context.put(PB_ST_VAR_CURRENT_USER_NAME, getLineValue(lines, PB_ST_VAR_CURRENT_USER_LABEL));
											result.context.put(PB_ST_VAR_START_TIME_NAME, getLineValue(lines, PB_ST_VAR_START_TIME_LABEL));
										}
										else if(blockName == PB_ST_HOW_START) {
											result.context.put(PB_ST_VAR_RUN_API_NAME, getLineValue(lines, PB_ST_VAR_RUN_API_LABEL));
										}
										else {
											// decisions blocks
											if(blockName.containsIgnoreCase(PB_ST_DECISION_NAME_PREFIX)) {
												String decisionName = lines.get(0);
												for(ProcessBuilderDecision pbd : result.decisions) {
													if(pbd.name == decisionName) {
														pbd.executed = true;
														parentDecisionIndex = pbd.index;
													}
												}
											}
											// all actions
											else {
												String actionAPIName = lines.get(0);
												for(ProcessBuilderDecision pbd : result.decisions) {

													if(pbd.index == parentDecisionIndex) {
														for(List<ProcessBuilderAction> pbaList : pbd.actions) {
															for(ProcessBuilderAction pba : pbaList) {
																if(pba.name == actionAPIName || pba.label == actionAPIName) {
																	parentActionAPIName = actionAPIName;
																	parentBlockName = blockname;
																	pba.executed = true;
																}
															}
														}
													}
												}
											}
										}
										blockName = null;
									}
									else if(childXmlNode.getText().contains('Error Occurred:')) {
										result.errorMessage = childXmlNode.getText();
									}
								}
							}
						}
					}
				}
			}
			try {
				result.apexStackTraceParseResults = StackTraceParser.parseStackTrace(result.errorMessage);
			}
			catch(Exception e) {}
		}
		return result;
	}

	public static String getProcessBuilderApiName(Dom.XmlNode[] rootElements) {
		String processBuilderAPIName = null;
		String blockName;
		String childsBlockLines;

		for(Dom.XmlNode xmlNode : rootElements) {
			Dom.XmlNodeType nodeType = xmlNode.getNodeType();

			switch on nodeType {
				when TEXT {}
				when ELEMENT {

					Dom.XmlNode[] elementNodes = xmlNode.getChildren();
					for (Dom.XmlNode childXmlNode : elementNodes) {
						Dom.XmlNodeType childNodeType = childXmlNode.getNodeType();
						switch on childNodeType {
							when ELEMENT {
								if (childXmlNode.getName() == HTML_TAG_SPAN) {
									blockName = childXmlNode.getText();
								}
							}
							when TEXT {
								if (blockName != null) {
									childsBlockLines = childXmlNode.getText();
									List<String> lines = childsBlockLines.split(PB_STACK_TRACE_EOL);
									if(PB_ST_FLOW_DETAILS == blockName) {
										processBuilderAPIName = getLineValue(lines, PB_ST_VAR_FLOW_API_NAME_LABEL);
									}
									blockName = null;
								}
							}
						}
					}
				}
			}
		}
		return processBuilderAPIName;
	}

	public static ProcessBuilder getProcessBuilder(String flowApiName, ProcessBuilderHelper helper) {
		ProcessBuilder result = new ProcessBuilder();

		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.setEndpointAndMetadataAPIVersion(StackTraceParser.corg.Instance_Url__c, PB_CURRENT_SUPPORTED_API_VERSION);
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = ConnectedOrgService.getConnectedOrgAccessToken(StackTraceParser.corg);

		MetadataService.Flow sfdcFlow =
			(MetadataService.Flow) service.readMetadata('Flow',
				new String[] {flowApiName}).getRecords()[0];

		if(sfdcFlow != null && sfdcFlow.fullName != null) {
			result.name = sfdcFlow.fullName;
			result.label = sfdcFlow.label;
			result.processType = sfdcFlow.processType;
			result.start = new ProcessBuilderStart(sfdcFlow.processType, sfdcFlow);
			getDecisions(result, sfdcFlow, helper);
		}
		if(result.decisions != null) {
			result.decisions.sort();
		}
		return result;
	}

	public static String getDecisionLabelByCriteriaName(MetadataService.FlowDecision flowDecision) {
		String result;
		for(MetadataService.FlowRule flowRule :flowDecision.rules) {
			result = flowRule.label;
			break;
		}
		return result;
	}

	public static void getDecisions(ProcessBuilder instance, MetadataService.Flow sfdcFlow, ProcessBuilderHelper helper) {
		if(sfdcFlow.decisions != null) {
			for(MetadataService.FlowDecision flowDecision : sfdcFlow.decisions) {
				Object decisionIndex = getProcessMetadataValue(PB_META_KEY_INDEX, flowDecision.processMetadataValues);
				if(flowDecision != null && decisionIndex != null) {
					ProcessBuilderDecision fDecision = new ProcessBuilderDecision();
					fDecision.name = flowDecision.name;
					fDecision.label = getDecisionLabelByCriteriaName(flowDecision);
					fDecision.index = String.valueOf(decisionIndex);

					addDecisionSections(flowDecision, fDecision, sfdcFlow);

					List<String> firstActionNames = getFirstActionNameFromDecision(flowDecision);
					getDecisionActions(instance, firstActionNames, sfdcFlow, fDecision.actions, new Set<String>(), helper);
					instance.decisions.add(fDecision);

				}
			}
		}
		return;
	}

	public static Set<String> getMainDecisionNames(MetadataService.Flow sfdcFlow) {
		Set<String> result = new Set<String>();
		for(MetadataService.FlowDecision flowDecision : sfdcFlow.decisions) {
			Object decisionIndex = getProcessMetadataValue(PB_META_KEY_INDEX, flowDecision.processMetadataValues);
			if(flowDecision != null && decisionIndex != null) {
				result.add(flowDecision.name);
			}
		}
		return result;
	}

	public static void getDecisionActions(
		ProcessBuilder instance,
		String nextActionName,
		MetadataService.Flow sfdcFlow,
		List<List<ProcessBuilderAction>> actions,
		Set<String> apiNames,
		ProcessBuilderHelper helper) {
		getDecisionActions(instance, new List<String>{nextActionName}, sfdcFlow, actions, apiNames, helper);
	}

	public static void getDecisionActions(
		ProcessBuilder instance,
		List<String> nextActionNames,
		MetadataService.Flow sfdcFlow,
		List<List<ProcessBuilderAction>> actions,
		Set<String> apiNames,
		ProcessBuilderHelper helper) {

		for(String nextActionName : nextActionNames) {

			// check loop metadata
			if(apiNames.contains(nextActionName)) return;

			if(sfdcFlow.decisions != null) {
				for(MetadataService.FlowDecision fDecision : sfdcFlow.decisions) {
					Object decisionIndex = getProcessMetadataValue(PB_META_KEY_INDEX, fDecision.processMetadataValues);
					if(fDecision.name == nextActionName && decisionIndex == null) {
						if(fDecision.rules != null) {
							for(MetadataService.FlowRule flowRule : fDecision.rules) {
								if(flowRule != null && flowRule.connector != null && flowRule.connector.targetReference != null) {
									getDecisionActions(instance, flowRule.connector.targetReference, sfdcFlow, actions, apiNames, helper);
								}
							}
						}
					}
				}
			}

			if(sfdcFlow.waits != null) {
				for(MetadataService.FlowWait flowWait : sfdcFlow.waits) {
					if(flowWait.name == nextActionName) {
						for(MetadataService.FlowWaitEvent flowWaitEvent : flowWait.waitEvents) {
							if(!apiNames.contains(flowWaitEvent.name)) {
								addFlowWaitSections(flowWaitEvent, actions);
								apiNames.add(flowWaitEvent.name);
							}
							if(flowWaitEvent != null && flowWaitEvent.connector != null && flowWaitEvent.connector.targetReference != null) {
								getDecisionActions(instance, flowWaitEvent.connector.targetReference, sfdcFlow, actions, apiNames, helper);
							}
						}
						return;
					}
				}
			}

			if(sfdcFlow.assignments != null) {
				for(MetadataService.FlowAssignment flowAssignment : sfdcFlow.assignments) {
					if(flowAssignment.name == nextActionName) {
						if(!apiNames.contains(flowAssignment.name)) {
							apiNames.add(flowAssignment.name);
						}
						if(flowAssignment.connector != null && flowAssignment.connector.targetReference != null) {
							getDecisionActions(instance, flowAssignment.connector.targetReference, sfdcFlow, actions, apiNames, helper);
						}
						return;
					}
				}
			}

			if(sfdcFlow.actionCalls != null) {
				for(MetadataService.FlowActionCall actionCall : sfdcFlow.actionCalls) {
					if(actionCall.name == nextActionName) {
						if(!apiNames.contains(actionCall.name)) {
							addActionCallSections(actionCall, actions, helper, sfdcFlow);
							apiNames.add(actionCall.name);
						}
						if(actionCall.connector != null && actionCall.connector.targetReference != null) {
							getDecisionActions(instance, actionCall.connector.targetReference, sfdcFlow, actions, apiNames, helper);
						}
						return;
					}
				}
			}

			if(sfdcFlow.recordCreates != null) {
				for(MetadataService.FlowRecordCreate recordCreate : sfdcFlow.recordCreates) {
					if(recordCreate.name == nextActionName) {
						if(!apiNames.contains(recordCreate.name)) {
							addRecordCreateSections(recordCreate, actions, sfdcFlow);
							apiNames.add(recordCreate.name);
						}
						if(recordCreate.connector != null && recordCreate.connector.targetReference != null) {
							getDecisionActions(instance, recordCreate.connector.targetReference, sfdcFlow, actions, apiNames, helper);
						}
						return;
					}
				}
			}

			if(sfdcFlow.recordUpdates != null) {
				for(MetadataService.FlowRecordUpdate recordUpdate : sfdcFlow.recordUpdates) {
					if(recordUpdate.name == nextActionName) {
						if(!apiNames.contains(recordUpdate.name)) {
							addRecordUpdateSections(recordUpdate, actions, sfdcFlow);
							apiNames.add(recordUpdate.name);
						}
						if(recordUpdate.connector != null && recordUpdate.connector.targetReference != null) {
							getDecisionActions(instance, recordUpdate.connector.targetReference, sfdcFlow, actions, apiNames, helper);
						}
						return;
					}
				}
			}
		}
		return;
	}

	public static void addDecisionSections(MetadataService.FlowDecision flowDecision, ProcessBuilderDecision fDecision, MetadataService.Flow sfdcFlow) {
		for(MetadataService.FlowRule fRule : flowDecision.rules) {

			SideBarSection criteriaNameSection = new SideBarSection(PB_LABEL_CRITERIA_NAME, SideBarItemType.TEXT)
				.addText(fRule.label);
			fDecision.sections.add(criteriaNameSection);

			Boolean isCriteriaFormula = (!fRule.conditions.isEmpty()
				&& fRule.conditions.size() == 1
				&& fRule.conditions.get(0).leftValueReference.startsWith(PB_META_KEY_VALUE_FORMULA_PREFIX)
				&& getFlowFormulaExpression(fRule.conditions.get(0).leftValueReference, sfdcFlow) != 'true');
			Boolean isNoCriteries = (!fRule.conditions.isEmpty()
				&& fRule.conditions.size() == 1
				&& fRule.conditions.get(0).leftValueReference.startsWith(PB_META_KEY_VALUE_FORMULA_PREFIX)
				&& getFlowFormulaExpression(fRule.conditions.get(0).leftValueReference, sfdcFlow) == 'true');
			Boolean isCritariaConditions = !isCriteriaFormula && !isNoCriteries;

			SideBarSection executingCriteriaSection = new SideBarSection(PB_LABEL_CRITERIA_EXECUTING_ACTIONS, SideBarItemType.RADIOBUTTON)
				.addRadioButton(isCritariaConditions, PB_LABEL_CONDITIONS_MET)
				.addRadioButton(isCriteriaFormula, PB_LABEL_FORMULA_EVALUATE)
				.addRadioButton(isNoCriteries, PB_LABEL_NO_CRITERIES);
			fDecision.sections.add(executingCriteriaSection);

			if(isCriteriaFormula) {
				SideBarSection criteriaFormulaSection = new SideBarSection(PB_LABEL_BUILD_FORMULA, SideBarItemType.TEXTAREA)
					.addText(getFlowFormulaValue(fRule.conditions.get(0).leftValueReference, sfdcFlow));
				fDecision.sections.add(criteriaFormulaSection);
			}

			if(isCritariaConditions) {
				SideBarSection conditionsSection = new SideBarSection(PB_LABEL_SET_CONDITIONS, SideBarItemType.TABLE);
				Integer indexCounter = 1;
				conditionsSection.addTableHeaders(new List<String>{null, PB_TABLE_LABEL_SOURCE, PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_OPERATOR, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});

				for(MetadataService.FlowCondition fc : fRule.conditions) {
					List<SideBarTableRow> rowObjects = new List<SideBarTableRow>();
					rowObjects.add(new SideBarTableRow(String.valueOf(indexCounter++)));
					rowObjects.add(new SideBarTableRow(fc.leftValueReference));
					rowObjects.add(new SideBarTableRow(String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_TYPE, fc.processMetadataValues))));
					rowObjects.add(new SideBarTableRow(OPERATORS_MAP.get(fc.operator)));

					String rowType = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, fc.processMetadataValues));
					rowObjects.add(new SideBarTableRow(rowType));

					String rowValue = String.valueOf(getFlowElementReferenceOrValue(fc.rightValue));
					rowValue = (rowType == PB_META_KEY_VALUE_FORMULA) ? getFlowFormulaValue(rowValue, sfdcFlow) : rowValue;
					rowObjects.add(new SideBarTableRow(rowValue, (rowType == PB_META_KEY_VALUE_FORMULA)));

					conditionsSection.addTableRows(rowObjects);
				}
				fDecision.sections.add(conditionsSection);

				SideBarSection conditionCriteriaSection = new SideBarSection(PB_LABEL_CRITERIA_EXECUTING_ACTIONS, SideBarItemType.RADIOBUTTON)
					.addRadioButton(fRule.conditionLogic == PB_META_KEY_VALUE_AND, PB_LABEL_ALL_CONDITIONS_MET)
					.addRadioButton(fRule.conditionLogic == PB_META_KEY_VALUE_OR, PB_LABEL_ANY_CONDITIONS_MET)
					.addRadioButton(fRule.conditionLogic != PB_META_KEY_VALUE_AND && fRule.conditionLogic != PB_META_KEY_VALUE_OR, PB_LABEL_CUSTOMIZE_LOGIC);
				fDecision.sections.add(conditionCriteriaSection);
			}
		}
	}

	public static void addFlowWaitSections(MetadataService.FlowWaitEvent flowWaitEvent, List<List<ProcessBuilderAction>> actions) {
		ProcessBuilderAction pba = new ProcessBuilderAction(flowWaitEvent.name, flowWaitEvent.label, PB_ACTION_TYPE_SCHEDULED_ACTION_START);
		pba.setIcon(PB_ICON_SCHEDULED_ACTION);
		MetadataService.FlowWaitEventInputParameter timeOffsetUnit = getInputParameterByName(PB_META_KEY_TIME_OFFSET_UNIT, flowWaitEvent.inputParameters);
		MetadataService.FlowWaitEventInputParameter timeOffset = getInputParameterByName(PB_META_KEY_TIME_OFFSET, flowWaitEvent.inputParameters);
		String sTimeOffsetUnit = String.valueOf(getFlowElementReferenceOrValue(timeOffsetUnit.value));
		String sTimeOffset = String.valueOf(getFlowElementReferenceOrValue(timeOffset.value));
		Integer timeOffsetInteger = Integer.valueOf(sTimeOffset);

		switch on flowWaitEvent.eventType {
			when 'AlarmEvent' {
				SideBarSection timeSection = new SideBarSection(PB_LABEL_SET_TIME_FOR_ACTIONS, SideBarItemType.TABLETIME)
					.addTableRows(new List<SideBarTableRow>{
						new SideBarTableRow(false),
						new SideBarTableRow(''),
						new SideBarTableRow(PB_LABEL_DAYS),
						new SideBarTableRow(PB_LABEL_TIME_AFTER),
						new SideBarTableRow('')
					})
					.addTableRows(new List<SideBarTableRow>{
						new SideBarTableRow(true),
						new SideBarTableRow(Math.abs(timeOffsetInteger)),
						new SideBarTableRow(sTimeOffsetUnit),
						new SideBarTableRow(PB_LABEL_TIME_FROM_NOW)
					});
				pba.sections.add(timeSection);
				pba.label = timeOffsetInteger + ' ' + sTimeOffsetUnit + ' ' + PB_LABEL_TIME_FROM_NOW;
			}
			when 'DateRefAlarmEvent' {
				MetadataService.FlowWaitEventInputParameter timeFieldColumnEnumOrId = getInputParameterByName(PB_META_KEY_TIME_FIELD_ENUM_OR_ID, flowWaitEvent.inputParameters);
				String sTimeFieldColumnEnumOrId = String.valueOf(getFlowElementReferenceOrValue(timeFieldColumnEnumOrId.value));
				String isBeforeAfter = (timeOffsetInteger < 0) ? PB_LABEL_TIME_BEFORE : PB_LABEL_TIME_AFTER;
				SideBarSection timeSection = new SideBarSection(PB_LABEL_SET_TIME_FOR_ACTIONS, SideBarItemType.TABLETIME)
					.addTableRows(new List<SideBarTableRow>{
						new SideBarTableRow(true),
						new SideBarTableRow(Math.abs(timeOffsetInteger)),
						new SideBarTableRow(sTimeOffsetUnit),
						new SideBarTableRow(isBeforeAfter),
						new SideBarTableRow(sTimeFieldColumnEnumOrId)
					})
					.addTableRows(new List<SideBarTableRow>{
						new SideBarTableRow(false),
						new SideBarTableRow(''),
						new SideBarTableRow(PB_LABEL_DAYS),
						new SideBarTableRow(PB_LABEL_TIME_FROM_NOW)
					});
				pba.sections.add(timeSection);
				pba.label = Math.abs(timeOffsetInteger) + ' ' + sTimeOffsetUnit + ' ' + isBeforeAfter + ' ' + sTimeFieldColumnEnumOrId;
			}
		}
		actions.add(new List<ProcessBuilderAction>{pba});
	}

	public static void addActionCallSections(MetadataService.FlowActionCall actionCall, List<List<ProcessBuilderAction>> actions, ProcessBuilderHelper helper, MetadataService.Flow sfdcFlow) {
		Integer index = (actions.size() == 0) ? 0 : actions.size() - 1;
		ProcessBuilderAction pba = new ProcessBuilderAction(actionCall.name, actionCall.label, PB_ACTION_TYPE_FLOW_ACTION_CALL);
		Set<String> decisionNames = getMainDecisionNames(sfdcFlow);
		pba.evaluateNextCriteria = (actionCall.connector != null && actionCall.connector.targetReference != null && decisionNames.contains(actionCall.connector.targetReference));

		switch on actionCall.actionType {
			when 'submit' {
				pba.setIcon(PB_ICON_SUBMIT_FOR_APPROVAL);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				SideBarSection objectSection = new SideBarSection(PB_LABEL_OBJECT, SideBarItemType.TEXT)
					.addText(String.valueOf(getProcessMetadataValue(PB_KEY_OBJECT_TYPE, sfdcFlow.processMetadataValues)));
				pba.sections.add(objectSection);

				String selectionType = String.valueOf(getProcessMetadataValue(PB_META_KEY_SELECTION_TYPE, actionCall.processMetadataValues));
				switch on selectionType {
					when 'firstFound' {
						SideBarSection approvalProcessSection = new SideBarSection(PB_LABEL_APPROVAL_PROCESS, SideBarItemType.TEXT)
							.addText(PB_LABEL_DEFAULT_APPROVAL_PROCESS);
						pba.sections.add(approvalProcessSection);
					}
					when 'selectedProcess' {
						String processSelection = String.valueOf(getProcessMetadataValue(PB_META_KEY_PROCESS_SELECTION, actionCall.processMetadataValues));

						SideBarSection approvalProcessSection = new SideBarSection(PB_LABEL_APPROVAL_PROCESS, SideBarItemType.TABLE)
							.addTableHeaders(new List<String>{'', ''})
							.addTableRows(new List<SideBarTableRow>{
								new SideBarTableRow(PB_LABEL_SPECIFIC_APPROVAL_PROCESS),
								new SideBarTableRow(processSelection)
							});
						pba.sections.add(approvalProcessSection);

						if(actionCall.inputParameters != null && !actionCall.inputParameters.isEmpty()) {
							MetadataService.FlowActionCallInputParameter skipEntryCriteria = getInputParameterByName(PB_META_KEY_SKIP_ENTRY_CRITERIA, actionCall.inputParameters);
							Boolean sSkipEntryCriteria = Boolean.valueOf(getFlowElementReferenceOrValue(skipEntryCriteria.value));

							SideBarSection skipEntrySection = new SideBarSection(PB_LABEL_SKIP_ENTRY_CRITERIA, SideBarItemType.CHECKBOX)
								.addCheckBox(sSkipEntryCriteria, PB_LABEL_YES);
							pba.sections.add(skipEntrySection);
						}
					}
				}

				SideBarSection submitterSection = new SideBarSection(PB_LABEL_SUBMITTER, SideBarItemType.TEXT)
					.addText(String.valueOf(getProcessMetadataValue(PB_META_KEY_SUBMITTER_TYPE, actionCall.processMetadataValues)));
				pba.sections.add(submitterSection);

				if(actionCall.inputParameters != null && !actionCall.inputParameters.isEmpty()) {
					MetadataService.FlowActionCallInputParameter comments = getInputParameterByName(PB_META_KEY_COMMENT, actionCall.inputParameters);
					String sComments = String.valueOf(getFlowElementReferenceOrValue(comments.value));

					SideBarSection commentsSection = new SideBarSection(PB_LABEL_SUBMISSION_COMMENTS, SideBarItemType.TEXTAREA)
						.addText(sComments);
					pba.sections.add(commentsSection);
				}
			}
			when 'flow' {
				pba.setIcon(PB_ICON_FLOW);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				SideBarSection typeSection = new SideBarSection(PB_LABEL_ACTION_FLOW, SideBarItemType.TEXT)
					.addText(String.valueOf(getProcessMetadataValue(PB_META_KEY_FLOW_SELECTION, actionCall.processMetadataValues)));
				pba.sections.add(typeSection);
			}
			when 'customNotificationAction' {
				pba.setIcon(PB_ICON_CUSTOM_NOTIFICATION);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				SideBarSection typeSection = new SideBarSection(PB_LABEL_NOTIFICATION_TYPE, SideBarItemType.TEXT)
					.addText(String.valueOf(getProcessMetadataValue(PB_META_KEY_CUSTOM_NOTIFICATION_TYPE, actionCall.processMetadataValues)));
				pba.sections.add(typeSection);

				if(actionCall.inputParameters != null && !actionCall.inputParameters.isEmpty()) {
					MetadataService.FlowActionCallInputParameter title = getInputParameterByName(PB_META_KEY_TITLE, actionCall.inputParameters);
					MetadataService.FlowActionCallInputParameter body = getInputParameterByName(PB_META_KEY_BODY, actionCall.inputParameters);
					String sTitle = String.valueOf(getFlowElementReferenceOrValue(title.value));
					String sBody = String.valueOf(getFlowElementReferenceOrValue(body.value));

					String sRecipientCategory = String.valueOf(getProcessMetadataValue(PB_META_KEY_RECIPIENT_CATEGORY, actionCall.processMetadataValues));
					String recipientCategoryValue = '';
					String sRecipientType = (getProcessMetadataValue(PB_META_KEY_RECIPIENT_TYPE, actionCall.processMetadataValues) != null) ? String.valueOf(getProcessMetadataValue(PB_META_KEY_RECIPIENT_TYPE, actionCall.processMetadataValues)) : '';
					String recipientTypeValue = '';

					switch on sRecipientCategory {
						when 'user' {
							recipientCategoryValue = PB_LABEL_QA_RECIPIENT_CATEGORY_USER;

							switch on sRecipientType {
								when 'currentUser' {
									recipientTypeValue = PB_LABEL_QA_RECIPIENT_CATEGORY_USER_CURRENT_USER;
									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_NOTIFICATION_RECIPIENT, PB_TABLE_LABEL_USER})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(recipientTypeValue)
										});
									pba.sections.add(recipientSection);
								}
								when 'user' {
									recipientTypeValue = PB_LABEL_QA_RECIPIENT_CATEGORY_USER_FIND_USER;
									String sRecipientSelection = String.valueOf(getProcessMetadataValue(PB_META_KEY_RECIPIENT_SELECTION, actionCall.processMetadataValues));

									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_NOTIFICATION_RECIPIENT, PB_TABLE_LABEL_USER, ''})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(recipientTypeValue),
											new SideBarTableRow(sRecipientSelection)
										});
									pba.sections.add(recipientSection);
								}
								when 'reference' {
									recipientTypeValue = PB_LABEL_QA_RECIPIENT_CATEGORY_USER_REFERENCE;

									MetadataService.FlowActionCallInputParameter recipientIds = getInputParameterByName(PB_META_KEY_RECIPIENT_IDS, actionCall.inputParameters);
									String sRecipientIds = String.valueOf(getFlowElementReferenceOrValue(recipientIds.value));
									String sRecipientIdsValue = getFlowAssigmentItemValue(sRecipientIds, sfdcFlow);

									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_NOTIFICATION_RECIPIENT, PB_TABLE_LABEL_USER, ''})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(recipientTypeValue),
											new SideBarTableRow(sRecipientIdsValue)
										});
									pba.sections.add(recipientSection);
								}
							}
						}
						when 'owner' {
							recipientCategoryValue = PB_LABEL_QA_RECIPIENT_CATEGORY_OWNER;
							switch on sRecipientType {
								when 'reference' {
									MetadataService.FlowActionCallInputParameter recipientIds = getInputParameterByName(PB_META_KEY_RECIPIENT_IDS, actionCall.inputParameters);
									String sRecipientIds = String.valueOf(getFlowElementReferenceOrValue(recipientIds.value));
									String sRecipientIdsValue = getFlowAssigmentItemValue(sRecipientIds, sfdcFlow);

									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_NOTIFICATION_RECIPIENT, ''})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(sRecipientIdsValue)
										});
									pba.sections.add(recipientSection);
								}
							}
						}
						when 'group' {
							recipientCategoryValue = PB_LABEL_QA_RECIPIENT_CATEGORY_GROUP;

							switch on sRecipientType {
								when 'record' {
									String sRecipientSelection = String.valueOf(getProcessMetadataValue(PB_META_KEY_RECIPIENT_SELECTION, actionCall.processMetadataValues));

									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_GROUP, ''})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(sRecipientSelection)
										});
									pba.sections.add(recipientSection);
								}
							}
						}
						when 'queue' {
							recipientCategoryValue = PB_LABEL_QA_RECIPIENT_CATEGORY_QUEUE;

							switch on sRecipientType {
								when 'record' {
									recipientTypeValue = PB_LABEL_QA_RECIPIENT_CATEGORY_QUEUE_RECORD;
									String sRecipientSelection = String.valueOf(getProcessMetadataValue(PB_META_KEY_RECIPIENT_SELECTION, actionCall.processMetadataValues));

									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_NOTIFICATION_RECIPIENT, PB_TABLE_LABEL_QUEUE, ''})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(recipientTypeValue),
											new SideBarTableRow(sRecipientSelection)
										});
									pba.sections.add(recipientSection);
								}
								when 'reference' {
									recipientTypeValue = PB_LABEL_QA_RECIPIENT_CATEGORY_QUEUE_REFERENCE;

									MetadataService.FlowActionCallInputParameter recipientIds = getInputParameterByName(PB_META_KEY_RECIPIENT_IDS, actionCall.inputParameters);
									String sRecipientIds = String.valueOf(getFlowElementReferenceOrValue(recipientIds.value));
									String sRecipientIdsValue = getFlowAssigmentItemValue(sRecipientIds, sfdcFlow);

									SideBarSection recipientSection = new SideBarSection('', SideBarItemType.TABLE)
										.addTableHeaders(new List<String>{PB_TABLE_LABEL_NOTIFICATION_RECIPIENT, PB_TABLE_LABEL_QUEUE, ''})
										.addTableRows(new List<SideBarTableRow>{
											new SideBarTableRow(recipientCategoryValue),
											new SideBarTableRow(recipientTypeValue),
											new SideBarTableRow(sRecipientIdsValue)
										});
									pba.sections.add(recipientSection);
								}
							}
						}
					}

					SideBarSection titleSection = new SideBarSection(PB_LABEL_NOTIFICATION_TITLE, SideBarItemType.TEXTAREA)
						.addText(sTitle);
					pba.sections.add(titleSection);
					SideBarSection bodySection = new SideBarSection(PB_LABEL_NOTIFICATION_BODY, SideBarItemType.TEXTAREA)
						.addText(sBody);
					pba.sections.add(bodySection);
				}
			}
			when 'quickAction' {
				pba.setIcon(PB_ICON_QUICK_ACTION);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				String filterType = String.valueOf(getProcessMetadataValue(PB_META_KEY_FILTER_TYPE, actionCall.processMetadataValues));
				String quickActionType = String.valueOf(getProcessMetadataValue(PB_META_KEY_QA_TYPE, actionCall.processMetadataValues));
				String filterTypeValue = '';
				String qaTypeValue = '';

				switch on filterType {
					when 'quickActionType' {
						filterTypeValue = PB_LABEL_QA_FILTER_TYPE;
					}
					when 'globalType' {
						filterTypeValue = PB_LABEL_QA_FILTER_GLOBAL;
					}
					when 'objectType' {
						filterTypeValue = PB_LABEL_QA_FILTER_OBJECT;
					}
				}
				switch on quickActionType {
					when 'create' {
						qaTypeValue = PB_LABEL_QA_FILTER_CREATE;
					}
					when 'update' {
						qaTypeValue = PB_LABEL_QA_FILTER_UPDATE;
					}
					when 'logACall' {
						qaTypeValue = PB_LABEL_QA_FILTER_LOG_A_CALL;
					}
				}

				SideBarSection actionSection = new SideBarSection('', SideBarItemType.TABLE)
					.addTableHeaders(new List<String>{PB_TABLE_LABEL_FILTER_SEARCH_BY, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_ACTION})
					.addTableRows(new List<SideBarTableRow>{
						new SideBarTableRow(filterTypeValue),
						new SideBarTableRow(qaTypeValue),
						new SideBarTableRow(actionCall.actionName)
					});
				pba.sections.add(actionSection);

				if(actionCall.inputParameters != null && !actionCall.inputParameters.isEmpty()) {
					SideBarSection qaFieldSection = new SideBarSection(PB_LABEL_SET_QA_FIELD_VALUES, SideBarItemType.TABLE)
						.addTableHeaders(new List<String>{PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});
					for(MetadataService.FlowActionCallInputParameter ip : actionCall.inputParameters) {
						String fieldLabel = String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_LABEL, ip.processMetadataValues));
						String rowType = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, ip.processMetadataValues));
						String rowValue = String.valueOf(getFlowElementReferenceOrValue(ip.value));

						qaFieldSection.addTableRows(new List<SideBarTableRow>{
							new SideBarTableRow(fieldLabel),
							new SideBarTableRow(rowType),
							new SideBarTableRow(rowValue)
						});
					}
					pba.sections.add(qaFieldSection);
				}
			}
			when 'chatterPost' {
				pba.setIcon(PB_ICON_CHATTER);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				if(actionCall.inputParameters != null && !actionCall.inputParameters.isEmpty()) {
					String postToValue;
					String sType;
					MetadataService.FlowActionCallInputParameter subjectNameOrId = getInputParameterByName(PB_META_KEY_SUBJECT_NAME_OR_ID, actionCall.inputParameters);
					MetadataService.FlowActionCallInputParameter ipType = getInputParameterByName(PB_META_KEY_TYPE, actionCall.inputParameters);
					String sSubjectNameOrId = String.valueOf(getFlowElementReferenceOrValue(subjectNameOrId.value));

					if(ipType.value == null) {
						postToValue = PB_LABEL_POST_TO_THIS_RECORD;
						SideBarSection postToSection = new SideBarSection(PB_LABEL_POST_TO, SideBarItemType.TEXT)
							.addText(sSubjectNameOrId);
						pba.sections.add(postToSection);
					}
					else {
						sType = String.valueOf(getFlowElementReferenceOrValue(ipType.value));
						if(sType == PB_META_KEY_VALUE_USER) {
							postToValue = PB_LABEL_POST_TO_CHATTER_USER;
							String userValue = (sSubjectNameOrId.startsWith(PB_META_KEY_VALUE_USER_ID_PREFIX)) ? PB_LABEL_SEARCH_USER : PB_LABEL_SELECT_USER;
							if(sSubjectNameOrId.startsWith(PB_META_KEY_VALUE_USER_ID_PREFIX)) {
								helper.userIds.add(sSubjectNameOrId);
								helper.actionNames.add(actionCall.name);
							}

							SideBarSection postToSection = new SideBarSection('', SideBarItemType.TABLE)
								.addTableHeaders(new List<String>{PB_TABLE_LABEL_POST_TO, PB_TABLE_LABEL_USER, null})
								.addTableRows(new List<SideBarTableRow>{
									new SideBarTableRow(postToValue),
									new SideBarTableRow(userValue),
									new SideBarTableRow(sSubjectNameOrId)
								});
							pba.sections.add(postToSection);
						}
						else if(sType == PB_META_KEY_VALUE_GROUP) {
							postToValue = PB_LABEL_POST_TO_CHATTER_GROUP;
							if(sSubjectNameOrId.startsWith(PB_META_KEY_VALUE_GROUP_ID_PREFIX)) {
								helper.groupIds.add(sSubjectNameOrId);
								helper.actionNames.add(actionCall.name);
							}
							SideBarSection postToSection = new SideBarSection('', SideBarItemType.TABLE)
								.addTableHeaders(new List<String>{PB_TABLE_LABEL_POST_TO, PB_TABLE_LABEL_GROUP})
								.addTableRows(new List<SideBarTableRow>{
									new SideBarTableRow(postToValue),
									new SideBarTableRow(sSubjectNameOrId)
								});
							pba.sections.add(postToSection);
						}
					}
				}

				String messageWrapperJson = String.valueOf(getProcessMetadataValue(PB_META_KEY_TEXT_JSON, actionCall.processMetadataValues));
				if(String.isNotBlank(messageWrapperJson)) {
					Map<String, Object> messageMap = (Map<String, Object>)JSON.deserializeUntyped(messageWrapperJson);
					if(messageMap != null && messageMap.containsKey(PB_META_KEY_MESSAGE)) {
						SideBarSection messageSection = new SideBarSection(PB_LABEL_MESSAGE, SideBarItemType.TEXTAREA)
							.addText(String.valueOf(messageMap.get(PB_META_KEY_MESSAGE)));
						pba.sections.add(messageSection);
					}
				}
			}
			when 'emailAlert' {
				pba.setIcon(PB_ICON_EMAIL_ALERT);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				SideBarSection emailAlertSection = new SideBarSection(PB_LABEL_EMAIL_ALERT, SideBarItemType.TEXT)
					.addText(String.valueOf(getProcessMetadataValue(PB_META_KEY_EMAIL_ALERT_SELECTION, actionCall.processMetadataValues)));
				pba.sections.add(emailAlertSection);
			}
			when 'apex' {
				pba.setIcon(PB_ICON_APEX);
				SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
					.addText(actionCall.label);
				pba.sections.add(actionNameSection);

				SideBarSection apexClassSection = new SideBarSection(PB_LABEL_APEX_CLASS, SideBarItemType.TEXT)
					.addText(String.valueOf(getProcessMetadataValue(PB_META_KEY_APEX_SELECTION, actionCall.processMetadataValues)));
				pba.sections.add(apexClassSection);

				if(actionCall.inputParameters != null && !actionCall.inputParameters.isEmpty()) {
					SideBarSection apexVariablesSection = new SideBarSection(PB_LABEL_SET_APEX_VARIABLES, SideBarItemType.TABLE)
						.addTableHeaders(new List<String>{PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});
					for(MetadataService.FlowActionCallInputParameter ip : actionCall.inputParameters) {
						String rowType = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, ip.processMetadataValues));
						String rowTypeLabel = FILTER_TYPE_MAP.get(rowType);
						Boolean isFieldReference = rowType == PB_LABEL_SOBJECT;
						String rowValue;
						if(isFieldReference) {
							String variableName = String.valueOf(getFlowElementReferenceOrValue(ip.value));
							MetadataService.FlowVariable variable = getFlowVariable(variableName, sfdcFlow);
							rowValue = variable.objectType;
						}
						rowValue = (isFieldReference) ? rowValue : PB_LABEL_GLOBAL_CONSTANT_NULL;

						apexVariablesSection.addTableRows(new List<SideBarTableRow>{
							new SideBarTableRow(String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_LABEL, ip.processMetadataValues))),
							new SideBarTableRow(rowTypeLabel),
							new SideBarTableRow(rowValue)
						});
					}
					pba.sections.add(apexVariablesSection);
				}
			}
		}
		actions.get(index).add(pba);
	}

	public static void addRecordCreateSections(MetadataService.FlowRecordCreate recordCreate, List<List<ProcessBuilderAction>> actions, MetadataService.Flow sfdcFlow) {
		Integer index = (actions.size() == 0) ? 0 : actions.size() - 1;
		ProcessBuilderAction pba = new ProcessBuilderAction(recordCreate.name, recordCreate.label, PB_ACTION_TYPE_FLOW_RECORD_CREATE);
		Set<String> decisionNames = getMainDecisionNames(sfdcFlow);
		pba.evaluateNextCriteria = (recordCreate.connector != null && recordCreate.connector.targetReference != null && decisionNames.contains(recordCreate.connector.targetReference));
		pba.setIcon(PB_ICON_RECORD_CREATE);
		actions.get(index).add(pba);
		SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
			.addText(recordCreate.label);
		pba.sections.add(actionNameSection);

		SideBarSection apexClassSection = new SideBarSection(PB_LABEL_RECORD_TYPE, SideBarItemType.TEXT)
			.addText(recordCreate.object_x);
		pba.sections.add(apexClassSection);

		if(recordCreate.inputAssignments != null && !recordCreate.inputAssignments.isEmpty()) {
			SideBarSection fieldValuesSection = new SideBarSection(PB_LABEL_SET_FIELD_VALUES, SideBarItemType.TABLE)
				.addTableHeaders(new List<String>{PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});
			for(MetadataService.FlowInputFieldAssignment ip : recordCreate.inputAssignments) {
				String fieldLabel = String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_LABEL, ip.processMetadataValues));
				String fieldType = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, ip.processMetadataValues));
				String fieldTypeLabel = FILTER_TYPE_MAP.get(fieldType);

				String rowValue = PB_LABEL_GLOBAL_CONSTANT_NULL;
				if(ip.value != null) {
					rowValue = String.valueOf(getFlowElementReferenceOrValue(ip.value));
					rowValue = (fieldType == PB_META_KEY_VALUE_FORMULA) ? getFlowFormulaValue(rowValue, sfdcFlow) : rowValue;
					rowValue = (String.isBlank(rowValue)) ? PB_LABEL_GLOBAL_CONSTANT_EMPTY_STRING : rowValue;
				}

				fieldValuesSection.addTableRows(new List<SideBarTableRow>{
					new SideBarTableRow(fieldLabel),
					new SideBarTableRow(fieldTypeLabel),
					new SideBarTableRow(rowValue, (fieldType == PB_META_KEY_VALUE_FORMULA))
				});
			}
			pba.sections.add(fieldValuesSection);
		}
	}

	public static void addRecordUpdateSections(MetadataService.FlowRecordUpdate recordUpdate, List<List<ProcessBuilderAction>> actions, MetadataService.Flow sfdcFlow) {
		Integer index = (actions.size() == 0) ? 0 : actions.size() - 1;
		ProcessBuilderAction pba = new ProcessBuilderAction(recordUpdate.name, recordUpdate.label, PB_ACTION_TYPE_FLOW_RECORD_UPDATE);
		Set<String> decisionNames = getMainDecisionNames(sfdcFlow);
		pba.evaluateNextCriteria = (recordUpdate.connector != null && recordUpdate.connector.targetReference != null && decisionNames.contains(recordUpdate.connector.targetReference));
		pba.setIcon(PB_ICON_RECORD_UPDATE);
		actions.get(index).add(pba);
		SideBarSection actionNameSection = new SideBarSection(PB_LABEL_ACTION_NAME, SideBarItemType.TEXT)
			.addText(recordUpdate.label);
		pba.sections.add(actionNameSection);

		SideBarSection recordSection = new SideBarSection(PB_LABEL_RECORD, SideBarItemType.TEXT)
			.addText(String.valueOf(getProcessMetadataValue(PB_META_KEY_REFERENCE, recordUpdate.processMetadataValues)));
		pba.sections.add(recordSection);

		if(recordUpdate.filters != null && !recordUpdate.filters.isEmpty()) {
			Boolean hasFilters = false;
			Integer indexCounter = 1;

			SideBarSection filterFiledSection = new SideBarSection(PB_LABEL_FILTER_RECORDS, SideBarItemType.TABLE)
				.addTableHeaders(new List<String>{null, PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_OPERATOR, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});

			for(MetadataService.FlowRecordFilter frf : recordUpdate.filters) {
				Boolean implicit = Boolean.valueOf(getProcessMetadataValue(PB_META_KEY_IMPLICIT, frf.processMetadataValues));
				if(!implicit) {
					hasFilters = true;

					String fieldLabel = String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_LABEL, frf.processMetadataValues));
					String fieldType = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, frf.processMetadataValues));
					String fieldTypeLabel = FILTER_TYPE_MAP.get(fieldType);

					String fieldValue = PB_LABEL_GLOBAL_CONSTANT_NULL;
					if(frf.value != null) {
						String sValue = getFlowElementReferenceOrValue(frf.value) != null ? String.valueOf(getFlowElementReferenceOrValue(frf.value)) : null;
						fieldValue = String.isNotBlank(sValue) ? sValue : PB_LABEL_GLOBAL_CONSTANT_EMPTY_STRING;
					}

					filterFiledSection.addTableRows(new List<SideBarTableRow>{
						new SideBarTableRow(String.valueOf(indexCounter++)),
						new SideBarTableRow(fieldLabel),
						new SideBarTableRow(OPERATORS_MAP.get(frf.operator)),
						new SideBarTableRow(fieldTypeLabel),
						new SideBarTableRow(fieldValue)
					});
				}
			}

			SideBarSection criteriaUpdatingSection = new SideBarSection(PB_LABEL_CRITERIA_UPDATING, SideBarItemType.RADIOBUTTON)
				.addRadioButton(hasFilters, PB_LABEL_CRITERIA_UPDATING_ALL_CONDITIONS)
				.addRadioButton(!hasFilters, PB_LABEL_CRITERIA_UPDATING_NO_CONDITIONS);
			pba.sections.add(criteriaUpdatingSection);

			if(hasFilters) {
				pba.sections.add(filterFiledSection);
			}
		}

		if(recordUpdate.inputAssignments != null && !recordUpdate.inputAssignments.isEmpty()) {
			SideBarSection fieldValuesSection = new SideBarSection(PB_LABEL_SET_NEW_FIELD_VALUES, SideBarItemType.TABLE)
				.addTableHeaders(new List<String>{PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});
			for(MetadataService.FlowInputFieldAssignment ip : recordUpdate.inputAssignments) {
				String fieldLabel = String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_LABEL, ip.processMetadataValues));
				String fieldType = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, ip.processMetadataValues));
				String fieldTypeLabel = FILTER_TYPE_MAP.get(fieldType);

				String rowValue = PB_LABEL_GLOBAL_CONSTANT_NULL;
				if(ip.value != null) {
					rowValue = String.valueOf(getFlowElementReferenceOrValue(ip.value));
					rowValue = (fieldType == PB_META_KEY_VALUE_FORMULA) ? getFlowFormulaValue(rowValue, sfdcFlow) : rowValue;
					rowValue = (String.isBlank(rowValue)) ? PB_LABEL_GLOBAL_CONSTANT_EMPTY_STRING : rowValue;
				}
				String rowValueLabel = String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_LABEL, ip.processMetadataValues));
				if(String.isNotBlank(rowValueLabel)) {
					pba.context.put(rowValueLabel, rowValue);
				}
				rowValue = (String.isNotBlank(rowValueLabel)) ? rowValueLabel : rowValue;

				fieldValuesSection.addTableRows(new List<SideBarTableRow>{
					new SideBarTableRow(fieldLabel),
					new SideBarTableRow(fieldTypeLabel),
					new SideBarTableRow(rowValue, (fieldType == PB_META_KEY_VALUE_FORMULA))
				});
			}
			pba.sections.add(fieldValuesSection);
		}
	}

	public static final String PB_ACTION_TYPE_FLOW_RECORD_UPDATE = 'FlowRecordUpdate';
	public static final String PB_ACTION_TYPE_FLOW_RECORD_CREATE = 'FlowRecordCreate';
	public static final String PB_ACTION_TYPE_FLOW_ACTION_CALL = 'FlowActionCall';
	public static final String PB_ACTION_TYPE_SCHEDULED_ACTION_START = 'FlowWait';

	public static final String PB_ICON_RECORD_UPDATE = 'update_record';
	public static final String PB_ICON_RECORD_CREATE = 'create_record';
	public static final String PB_ICON_APEX = 'apex';
	public static final String PB_ICON_EMAIL_ALERT = 'send_email';
	public static final String PB_ICON_CHATTER = 'chatter';
	public static final String PB_ICON_QUICK_ACTION = 'quick_actions';
	public static final String PB_ICON_CUSTOM_NOTIFICATION = 'custom_notification';
	public static final String PB_ICON_FLOW = 'launch_flow';
	public static final String PB_ICON_SUBMIT_FOR_APPROVAL = 'submit_approval';
	public static final String PB_ICON_SCHEDULED_ACTION = 'clock';

	public static final String PB_KEY_OBJECT_TYPE = 'ObjectType';
	public static final String PB_KEY_OBJECT_VARIABLE = 'ObjectVariable';
	public static final String PB_KEY_OLD_OBJECT_VARIABLE = 'OldObjectVariable';
	public static final String PB_KEY_TRIGGER_TYPE = 'TriggerType';
	public static final String PB_KEY_EVENT_TYPE = 'EventType';

	public static final String PK_KEY_TRIGGER_TYPE_INSERT = 'onCreateOnly';
	public static final String PK_KEY_TRIGGER_TYPE_UPDATE = 'onAllChanges';

	public static final String PB_LABEL_PLATFORM_EVENT = 'Platform Event';
	public static final String PB_LABEL_OBJECT = 'Object';
	public static final String PB_LABEL_MATCHING_CONDITIONS = 'Matching Conditions';
	public static final String PB_LABEL_START_THE_PROCESS = 'Start the process';
	public static final String PB_LABEL_TRIGGER_TYPE_INSERT = 'only when a record is created';
	public static final String PB_LABEL_TRIGGER_TYPE_UPDATE = 'when a record is created or edited';
	public static final String PB_LABEL_RECURSION_RPOCESS = 'Recursion - Allow process to evaluate a record multiple times in a single save operation?';
	public static final String PB_LABEL_YES = 'Yes';
	public static final String PB_LABEL_SKIP_ENTRY_CRITERIA = 'Skip the entry criteria for this process?';
	public static final String PB_LABEL_APPROVAL_PROCESS = 'Approval Process';
	public static final String PB_LABEL_DEFAULT_APPROVAL_PROCESS = 'Default approval process';
	public static final String PB_LABEL_SPECIFIC_APPROVAL_PROCESS = 'Specific approval process';
	public static final String PB_LABEL_SET_NEW_FIELD_VALUES = 'Set new field values for the records you update';
	public static final String PB_LABEL_CRITERIA_UPDATING = 'Criteria for Updating Records';
	public static final String PB_LABEL_CRITERIA_UPDATING_ALL_CONDITIONS = 'Updated records meet all conditions';
	public static final String PB_LABEL_CRITERIA_UPDATING_NO_CONDITIONS = 'No criteria—just update the records!';
	public static final String PB_LABEL_FILTER_RECORDS = 'Filter the records you update based on these conditions';
	public static final String PB_LABEL_RECORD = 'Record';
	public static final String PB_LABEL_ACTION_NAME = 'Action Name';
	public static final String PB_LABEL_DAYS = 'Days';
	public static final String PB_LABEL_TIME_FROM_NOW = 'From now';
	public static final String PB_LABEL_SET_TIME_FOR_ACTIONS = 'Set Time for Actions to Execute';
	public static final String PB_LABEL_TIME_BEFORE = 'Before';
	public static final String PB_LABEL_TIME_AFTER = 'After';
	public static final String PB_LABEL_SUBMISSION_COMMENTS = 'Submission Comments';
	public static final String PB_LABEL_SUBMITTER = 'Submitter';
	public static final String PB_LABEL_ACTION_FLOW = 'Flow';
	public static final String PB_LABEL_RECORD_TYPE = 'Record Type';
	public static final String PB_LABEL_SET_FIELD_VALUES = 'Set Field Values';
	public static final String PB_LABEL_GLOBAL_CONSTANT_NULL = '$GlobalConstant.Null';
	public static final String PB_LABEL_GLOBAL_CONSTANT_EMPTY_STRING = '$GlobalConstant.EmptyString';
	public static final String PB_LABEL_SOBJECT = 'SObject';
	public static final String PB_LABEL_SET_APEX_VARIABLES = 'Set Apex Variables';
	public static final String PB_LABEL_APEX_CLASS = 'Apex Class';
	public static final String PB_LABEL_EMAIL_ALERT = 'Email Alert';
	public static final String PB_LABEL_MESSAGE = 'Message';
	public static final String PB_LABEL_POST_TO = 'Post to';
	public static final String PB_LABEL_POST_TO_CHATTER_GROUP = 'Chatter Group';
	public static final String PB_LABEL_POST_TO_CHATTER_USER = 'User';
	public static final String PB_LABEL_POST_TO_THIS_RECORD = 'This Record';
	public static final String PB_LABEL_SEARCH_USER = 'Search for a user';
	public static final String PB_LABEL_SELECT_USER = 'Select a user from a record';
	public static final String PB_LABEL_SET_QA_FIELD_VALUES = 'Set Quick Action Field Values';
	public static final String PB_LABEL_QA_FILTER_TYPE = 'Type';
	public static final String PB_LABEL_QA_FILTER_GLOBAL = 'Global';
	public static final String PB_LABEL_QA_FILTER_OBJECT = 'Object';
	public static final String PB_LABEL_QA_FILTER_CREATE = 'Create a Record';
	public static final String PB_LABEL_QA_FILTER_UPDATE = 'Update a Record';
	public static final String PB_LABEL_QA_FILTER_LOG_A_CALL = 'Log a Call';
	public static final String PB_LABEL_NOTIFICATION_TITLE = 'Notification Title';
	public static final String PB_LABEL_NOTIFICATION_BODY = 'Notification Body';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_USER = 'User';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_OWNER = 'Owner';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_GROUP = 'Group';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_QUEUE = 'Queue';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_USER_CURRENT_USER = 'Current User';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_USER_FIND_USER = 'Find User';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_USER_REFERENCE = 'User Field from a Record';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_QUEUE_RECORD = 'Find Queue';
	public static final String PB_LABEL_QA_RECIPIENT_CATEGORY_QUEUE_REFERENCE = 'Queue Field from a Record';
	public static final String PB_LABEL_NOTIFICATION_TYPE = 'Notification Type';
	public static final String PB_LABEL_SET_CONDITIONS = 'Set Conditions';
	public static final String PB_LABEL_BUILD_FORMULA = 'Build Formula';
	public static final String PB_LABEL_ALL_CONDITIONS_MET = 'All of the conditions are met (AND)';
	public static final String PB_LABEL_ANY_CONDITIONS_MET = 'Any of the conditions are met (OR)';
	public static final String PB_LABEL_CRITERIA_EXECUTING_ACTIONS = 'Criteria for Executing Actions';
	public static final String PB_LABEL_CUSTOMIZE_LOGIC = 'Customize the logic';

	public static final String PB_TABLE_LABEL_FIELD = 'Field';
	public static final String PB_TABLE_LABEL_SOURCE = 'Source';
	public static final String PB_TABLE_LABEL_OPERATOR = 'Operator';
	public static final String PB_TABLE_LABEL_TYPE = 'Type';
	public static final String PB_TABLE_LABEL_VALUE = 'Value';
	public static final String PB_TABLE_LABEL_POST_TO = 'Post to';
	public static final String PB_TABLE_LABEL_GROUP = 'Group';
	public static final String PB_TABLE_LABEL_USER = 'User';
	public static final String PB_TABLE_LABEL_FILTER_SEARCH_BY = 'Filter Search By';
	public static final String PB_TABLE_LABEL_ACTION = 'Action';
	public static final String PB_TABLE_LABEL_NOTIFICATION_RECIPIENT = 'Notification Recipient';
	public static final String PB_TABLE_LABEL_QUEUE = 'Queue';
	public static final String PB_LABEL_CRITERIA_NAME = 'Criteria Name';
	public static final String PB_LABEL_CONDITIONS_MET = 'Conditions are met';
	public static final String PB_LABEL_FORMULA_EVALUATE = 'Formula evaluates to true';
	public static final String PB_LABEL_NO_CRITERIES = 'No criteria—just execute the actions!';

	public static final String PB_META_KEY_LEFT_HAND_SIDE_LABEL = 'leftHandSideLabel';
	public static final String PB_META_KEY_LEFT_HAND_SIDE_TYPE = 'leftHandSideType';
	public static final String PB_META_KEY_RIGHT_HAND_SIDE_TYPE = 'rightHandSideType';
	public static final String PB_META_KEY_RIGHT_HAND_SIDE_LABEL = 'rightHandSideLabel';
	public static final String PB_META_KEY_RECURSIVE_COUNT_VARIABLE = 'RecursiveCountVariable';
	public static final String PB_META_KEY_IMPLICIT = 'implicit';
	public static final String PB_META_KEY_REFERENCE = 'reference';
	public static final String PB_META_KEY_APEX_SELECTION = 'apexSelection';
	public static final String PB_META_KEY_EMAIL_ALERT_SELECTION = 'emailAlertSelection';
	public static final String PB_META_KEY_TEXT_JSON = 'textJson';
	public static final String PB_META_KEY_MESSAGE = 'message';
	public static final String PB_META_KEY_SUBJECT_NAME_OR_ID = 'subjectNameOrId';
	public static final String PB_META_KEY_TYPE = 'type';
	public static final String PB_META_KEY_FILTER_TYPE = 'filterType';
	public static final String PB_META_KEY_QA_TYPE = 'quickActionType';
	public static final String PB_META_KEY_RECIPIENT_IDS = 'recipientIds';
	public static final String PB_META_KEY_RECIPIENT_SELECTION = 'recipientSelection';
	public static final String PB_META_KEY_RECIPIENT_TYPE = 'recipientType';
	public static final String PB_META_KEY_RECIPIENT_CATEGORY = 'recipientCategory';
	public static final String PB_META_KEY_TITLE = 'title';
	public static final String PB_META_KEY_BODY = 'body';
	public static final String PB_META_KEY_CUSTOM_NOTIFICATION_TYPE = 'customNotifTypeName';
	public static final String PB_META_KEY_FLOW_SELECTION = 'flowSelection';
	public static final String PB_META_KEY_COMMENT = 'comment';
	public static final String PB_META_KEY_SUBMITTER_TYPE = 'submitterType';
	public static final String PB_META_KEY_SKIP_ENTRY_CRITERIA = 'skipEntryCriteria';
	public static final String PB_META_KEY_PROCESS_SELECTION = 'processSelection';
	public static final String PB_META_KEY_SELECTION_TYPE = 'selectionType';
	public static final String PB_META_KEY_TIME_FIELD_ENUM_OR_ID = 'TimeFieldColumnEnumOrId';
	public static final String PB_META_KEY_TIME_OFFSET ='TimeOffset';
	public static final String PB_META_KEY_TIME_OFFSET_UNIT ='TimeOffsetUnit';
	public static final String PB_META_KEY_VALUE_AND = 'and';
	public static final String PB_META_KEY_VALUE_OR = 'or';
	public static final String PB_META_KEY_VALUE_FORMULA = 'Formula';
	public static final String PB_META_KEY_INDEX = 'index';

	public static final String PB_META_KEY_VALUE_USER = 'USER';
	public static final String PB_META_KEY_VALUE_GROUP = 'GROUP';
	public static final String PB_META_KEY_VALUE_USER_ID_PREFIX = '005';
	public static final String PB_META_KEY_VALUE_GROUP_ID_PREFIX = '0F9';
	public static final String PB_META_KEY_VALUE_FORMULA_PREFIX = 'formula_';
	public static final String PB_META_KEY_VALUE_FIRST_DECISION_INDEX = '0.0';

	public static final String PB_ST_DECISION_NAME_PREFIX = 'DECISION:';
	public static final String PB_ST_HOW_START = 'How the Interview Started';
	public static final String PB_ST_FLOW_INTERVIEW_DETAILS = 'Flow Interview Details';
	public static final String PB_ST_FLOW_DETAILS = 'Flow Details';
	public static final String PB_ST_COMMON_VAR_NAME = 'myVariable';
	public static final String PB_ST_VAR_FLOW_API_NAME_LABEL = 'Flow API Name';
	public static final String PB_ST_VAR_FLOW_API_NAME_NAME = 'FlowAPIName';
	public static final String PB_ST_VAR_TYPE_LABEL = 'Type';
	public static final String PB_ST_VAR_TYPE_NAME = 'Type';
	public static final String PB_ST_VAR_STATUS_LABEL = 'Status';
	public static final String PB_ST_VAR_STATUS_NAME = 'Status';
	public static final String PB_ST_VAR_ORG_LABEL = 'Org';
	public static final String PB_ST_VAR_ORG_NAME = 'Org';
	public static final String PB_ST_VAR_VERSION_LABEL = 'Version';
	public static final String PB_ST_VAR_VERSION_NAME = 'Version';
	public static final String PB_ST_VAR_CURRENT_USER_LABEL = 'Current User';
	public static final String PB_ST_VAR_CURRENT_USER_NAME = 'CurrentUser';
	public static final String PB_ST_VAR_START_TIME_LABEL = 'Start time';
	public static final String PB_ST_VAR_START_TIME_NAME = 'StartTime';
	public static final String PB_ST_VAR_RUN_API_LABEL = 'API Version for Running the Flow';
	public static final String PB_ST_VAR_RUN_API_NAME = 'APIVersionforRunningtheFlow';


	public static MetadataService.FlowWaitEventInputParameter getInputParameterByName(String name, List<MetadataService.FlowWaitEventInputParameter> parameters) {
		for(MetadataService.FlowWaitEventInputParameter ip : parameters) {
			if(ip.name == name) {
				return ip;
			}
		}
		return null;
	}

	public static MetadataService.FlowActionCallInputParameter getInputParameterByName(String name, List<MetadataService.FlowActionCallInputParameter> parameters) {
		for(MetadataService.FlowActionCallInputParameter ip : parameters) {
			if(ip.name == name) {
				return ip;
			}
		}
		return null;
	}

	public static MetadataService.FlowVariable getFlowVariable(String name, MetadataService.Flow sfdcFlow) {
		MetadataService.FlowVariable result;
		for(MetadataService.FlowVariable fVariable : sfdcFlow.variables) {
			if(fVariable.name == name) {
				result = fVariable;
				break;
			}
		}
		return result;
	}

	public static String getFlowAssigmentItemValue(String name, MetadataService.Flow sfdcFlow) {
		String result;
		for(MetadataService.FlowAssignment assignment : sfdcFlow.assignments) {
			for(MetadataService.FlowAssignmentItem assignmentItem : assignment.assignmentItems) {
				if(assignmentItem.assignToReference == name) {
					result = String.valueOf(getFlowElementReferenceOrValue(assignment.assignmentItems.get(0).value));
					break;
				}
			}
		}
		return result;
	}

	public static MetadataService.FlowRecordLookup  getRecordLookupByName(String recordLookupName, List<MetadataService.FlowRecordLookup> recordLookups) {
		MetadataService.FlowRecordLookup result;

		for(MetadataService.FlowRecordLookup rl : recordLookups) {
			if(rl.name == recordLookupName) {
				result = rl;
				break;
			}
		}
		return result;
	}

	public static MetadataService.FlowDecision getDecisionByName(String decisionName, List<MetadataService.FlowDecision> decisions) {
		MetadataService.FlowDecision result;

		for(MetadataService.FlowDecision fd : decisions) {
			if(fd.name == decisionName) {
				result = fd;
				break;
			}
		}
		return result;
	}

	public static List<String> getFirstActionNameFromDecision(MetadataService.FlowDecision flowDecision) {
		List<String> result = new List<String>();

		for(MetadataService.FlowRule flowRule :flowDecision.rules) {
			if(flowRule != null && flowRule.connector != null && flowRule.connector.targetReference != null) {
				result.add(flowRule.connector.targetReference);
			}
		}
		if(result.isEmpty()) {
			if(flowDecision.defaultConnector != null && flowDecision.defaultConnector.targetReference != null) {
				result.add(flowDecision.defaultConnector.targetReference);
			}
		}
		return result;
	}

	public static String getNextDecisionName(MetadataService.FlowDecision flowDecision) {
		String result;
		if(flowDecision.defaultConnector != null && flowDecision.defaultConnector.targetReference != null) {
			result = flowDecision.defaultConnector.targetReference;
		}
		return result;
	}

	public static String getFlowFormulaValue(String flowFormulaName, MetadataService.Flow sfdcFlow) {
		String result;
		for(MetadataService.FlowFormula ff : sfdcFlow.formulas) {
			if(ff.name == flowFormulaName) {
				result = String.valueOf(getProcessMetadataValue('originalFormula', ff.processMetadataValues));
				break;
			}
		}
		return result;
	}

	public static String getFlowFormulaExpression(String flowFormulaName, MetadataService.Flow sfdcFlow) {
		String result;
		for(MetadataService.FlowFormula ff : sfdcFlow.formulas) {
			if(ff.name == flowFormulaName) {
				result = ff.expression;
				break;
			}
		}
		return result;
	}

	public static Object getProcessMetadataValue(String key, MetadataService.FlowMetadataValue[] processMetadataValues) {
		Object result;
		if(processMetadataValues != null) {
			for(MetadataService.FlowMetadataValue flowValue : processMetadataValues) {
				if(flowValue.name == key) {
					result = getFlowElementReferenceOrValue(flowValue.value);
					break;
				}
			}
		}
		return result;
	}

	public static Object getFlowElementReferenceOrValue(MetadataService.FlowElementReferenceOrValue value) {
		Object result;
		if(value == null) return null;
		if(value.booleanValue != null) {
			return value.booleanValue;
		}
		else if(value.dateTimeValue != null) {
			return value.dateTimeValue;
		}
		else if(value.dateValue != null) {
			return value.dateValue;
		}
		else if(value.elementReference != null) {
			return value.elementReference;
		}
		else if(value.numberValue != null) {
			return value.numberValue;
		}
		else if(value.stringValue != null) {
			return value.stringValue;
		}
		return result;
	}

	public static Map<String, Object> getContextVariables(List<String> lines, Map<String, Object> exist) {
		Map<String, Object> result = (exist == null) ? new Map<String, Object>() : exist;

		for(String line : lines) {
			if(String.isNotBlank(line)) {
				Pattern JIRA_HASH_PATTERN = Pattern.compile('\\{\\!myVariable_(current|old|myEvent)\\.*(.*?)\\}\\s\\((.*?)\\)');
				Matcher m = JIRA_HASH_PATTERN.matcher(line);
				while(m.find()) {
					String variable = m.group(1);
					String fieldName = m.group(2);
					String value = m.group(3);

					String varName = variable;

					Map<String, Object> varFields = (result.get(varName) != null) ? (Map<String, Object>)result.get(varName) : new Map<String, Object>();
					varFields.put(fieldName, value);
					result.put(varName, varFields);
				}
			}
		}
		return result;
	}

	public static MetadataService.FlowDecision getFirstFlowDecision(MetadataService.Flow sfdcFlow) {
		for(MetadataService.FlowDecision flowDecision : sfdcFlow.decisions) {
			String index = String.valueOf(getProcessMetadataValue(PB_META_KEY_INDEX, flowDecision.processMetadataValues));
			if(PB_META_KEY_VALUE_FIRST_DECISION_INDEX == index) {
				return flowDecision;
			}
		}
		return null;
	}

	public static String getLineValue(List<String> lines, String paramName) {
		return getLineValue(lines, paramName, ':');
	}

	private static String getLineValue(List<String> lines, String paramName, String separator) {
		for(String line : lines) {
			if(String.isNotBlank(line)) {
				if(line.containsIgnoreCase(paramName)) {
					List<String> paramValuePar = line.split(separator);
					if(paramValuePar.size() == 2) {
						String value = paramValuePar.get(1).trim();
						return value;
					}
				}
			}
		}
		return null;
	}

	public static final Map<String, String> OPERATORS_MAP = new Map<String, String>{
		'EqualTo' => 'Equals',
		'NotEqualTo' => 'Does not equal',
		'StartsWith' => 'Starts with',
		'EndsWith' => 'Ends With',
		'Contains' => 'Contains',
		'IsNull' => 'Is null',
		'GreaterThan' => 'Greater than',
		'GreaterThanOrEqualTo' => 'Greater than or equal',
		'LessThan' => 'Less than',
		'LessThanOrEqualTo' => 'Less than or equal'
	};

	public static final Map<String, String> FILTER_TYPE_MAP = new Map<String, String>{
		'String' => 'String',
		'Reference' => 'Field Reference',
		'GlobalConstant' => 'Global Constant',
		'Formula' => 'Formula',
		'Picklist' => 'Picklist',
		'DateTime' => 'Date/Time',
		'Date' => 'Date',
		'Currency' => 'Currency',
		'Number' => 'Number',
		'ID' => 'ID',
		'User' => 'User',
		'Boolean' => 'Boolean',
		'Queue' => 'Queue'
	};

	public Enum SideBarItemType {
		TEXT,
		CHECKBOX,
		RADIOBUTTON,
		TABLE,
		INDEX,
		TEXTAREA,
		TABLETIME
	}

	public class SideBarSection {
		public String label;
		public Object value;
		public SideBarItemType itemType;
		public List<String> headers;
		public List<List<SideBarTableRow>> rows;
		public List<SideBarSimpleRow> items;

		public SideBarSection(String label, SideBarItemType itemType) {
			this.label = label;
			this.itemType = itemType;
		}

		public SideBarSection addText(Object value) {
			this.value = value;
			return this;
		}

		public SideBarSection addCheckBox(Object value, String label) {
			if(this.items == null) {
				this.items = new List<SideBarSimpleRow>();
			}
			this.items.add(new SideBarSimpleRow(value, label));
			return this;
		}

		public SideBarSection addRadioButton(Object value, String label) {
			if(this.items == null) {
				this.items = new List<SideBarSimpleRow>();
			}
			this.items.add(new SideBarSimpleRow(value, label));
			return this;
		}

		public SideBarSection addTableHeaders(List<String> headers) {
			this.headers = headers;
			return this;
		}

		public SideBarSection addTableRows(List<SideBarTableRow> rows) {
			if(this.rows == null) {
				this.rows = new List<List<SideBarTableRow>>();
			}
			this.rows.add(rows);
			return this;
		}
	}

	public class SideBarTableRow {
		public Object v;
		public Boolean f;

		public SideBarTableRow(Object value) {
			this.v = value;
			this.f = false;
		}
		public SideBarTableRow(Object value, Boolean isFunction) {
			this.v = value;
			this.f = isFunction;
		}
	}

	public class SideBarSimpleRow {
		public Object v;
		public String l;

		public SideBarSimpleRow(Object value, String label) {
			this.v = value;
			this.l = label;
		}
	}

	public class ProcessBuilderHelper {
		public List<String> userIds;
		public List<String> groupIds;
		public Map<String, String> mapUsers;
		public Map<String, String> mapGroups;
		public Set<String> actionNames;

		public ProcessBuilderHelper() {
			this.userIds = new List<String>();
			this.groupIds = new List<String>();
			this.mapUsers = new Map<String, String>();
			this.mapGroups = new Map<String, String>();
			this.actionNames = new Set<String>();
		}

		public void replaceIdsByNames(ProcessBuilder result) {
			if(!this.actionNames.isEmpty()) {
				if(!this.userIds.isEmpty()) {
					this.mapUsers = getUserMaps(this.userIds);
				}
				if(!this.groupIds.isEmpty()) {
					this.mapGroups = getGroupMaps(this.groupIds);
				}
			}
			for(ProcessBuilderDecision decision : result.decisions) {
				for(List<ProcessBuilderAction> actions : decision.actions) {
					for(ProcessBuilderAction action : actions) {
						if(this.actionNames.contains(action.name)) {
							for(SideBarSection sideBarSection : action.sections) {
								if(sideBarSection.itemType == SideBarItemType.TABLE) {
									for(List<SideBarTableRow> row : sideBarSection.rows) {
										SideBarTableRow lastCellInRow = row.get(row.size() - 1);
										String idValue = String.valueOf(lastCellInRow.v);
										if(this.userIds.contains(idValue)) {
											String name = this.mapUsers.get(idValue);
											if(String.isNotBlank(name)) {
												row.get(row.size() - 1).v = name;
											}
										}
										if(this.groupIds.contains(idValue)) {
											String name = this.mapGroups.get(idValue);
											if(String.isNotBlank(name)) {
												row.get(row.size() - 1).v = name;
											}
										}
									}
								}
							}
						}
					}
				}
			}

		}
	}

	public class ProcessBuilder {
		public String name;
		public String label;
		public String processType;
		public ProcessBuilderStart start;
		public List<ProcessBuilderDecision> decisions;
		public Map<String, Object> context;
		public List<StackTraceParser.StackTraceParseResult> apexStackTraceParseResults;
		public String errorMessage;

		public ProcessBuilder(){
			this.start = new ProcessBuilderStart();
			this.decisions = new List<ProcessBuilderDecision>();
			this.context = new Map<String, Object>();
			this.apexStackTraceParseResults = new List<StackTraceParser.StackTraceParseResult>();
		}
	}

	public class ProcessBuilderDecision implements Comparable {
		public String name;
		public String label;
		public String index;
		public Boolean executed;
		public List<List<ProcessBuilderAction>> actions;
		public Map<String, Object> context;

		public List<SideBarSection> sections;

		public ProcessBuilderDecision() {
			this.executed = false;
			this.actions = new List<List<ProcessBuilderAction>>();
			this.actions.add(new List<ProcessBuilderAction>());
			this.context = new Map<String, Object>();

			this.sections = new List<SideBarSection>();
		}

		public Integer compareTo(Object compareTo) {
			ProcessBuilderDecision mf = (ProcessBuilderDecision)compareTo;
			return this.index.compareTo(mf.index);
		}
	}

	public class ProcessBuilderAction {
		public String name;
		public String label;
		public String actionType;
		public Boolean executed;
		public Boolean evaluateNextCriteria;
		public Map<String, Object> context;
		public String icon;

		public List<SideBarSection> sections;

		public ProcessBuilderAction(String name, String label, String actionType) {
			this.name = name;
			this.label = label;
			this.actionType = actionType;
			this.executed = false;
			this.context = new Map<String, Object>();

			this.sections = new List<SideBarSection>();
			this.evaluateNextCriteria = false;
		}

		public void setIcon(String icon) {
			this.icon = icon;
		}

	}

	public class ProcessBuilderStart {
		public String startType;
		public String objectType;
		public String objectVariable;
		public String oldObjectVariable;
		public String triggerType;
		public String eventType;

		public List<SideBarSection> sections;

		public ProcessBuilderStart(){}

		public ProcessBuilderStart(String startType, MetadataService.Flow sfdcFlow) {

			this.startType = startType;
			this.objectType = String.valueOf(getProcessMetadataValue(PB_KEY_OBJECT_TYPE, sfdcFlow.processMetadataValues));
			this.objectVariable = String.valueOf(getProcessMetadataValue(PB_KEY_OBJECT_VARIABLE, sfdcFlow.processMetadataValues));
			this.oldObjectVariable = String.valueOf(getProcessMetadataValue(PB_KEY_OLD_OBJECT_VARIABLE, sfdcFlow.processMetadataValues));
			this.triggerType = String.valueOf(getProcessMetadataValue(PB_KEY_TRIGGER_TYPE, sfdcFlow.processMetadataValues));
			this.eventType = String.valueOf(getProcessMetadataValue(PB_KEY_EVENT_TYPE, sfdcFlow.processMetadataValues));

			this.sections = new List<SideBarSection>();
			// started from PlatformEvent
			if(String.isNotBlank(this.eventType) && this.eventType != 'null') {
				SideBarSection eventSection = new SideBarSection(PB_LABEL_PLATFORM_EVENT, SideBarItemType.TEXT)
					.addText(this.eventType);

				SideBarSection objectSection = new SideBarSection(PB_LABEL_OBJECT, SideBarItemType.TEXT)
					.addText(this.objectType);

				this.sections.add(eventSection);
				this.sections.add(objectSection);

				String startRefferenceName = sfdcFlow.startElementReference;
				if(String.isNotBlank(startRefferenceName)) {
					MetadataService.FlowRecordLookup recordLookup = getRecordLookupByName(startRefferenceName, sfdcFlow.recordLookups);
					if(recordLookup != null) {
						SideBarSection conditionsSection = new SideBarSection(PB_LABEL_MATCHING_CONDITIONS, SideBarItemType.TABLE);
						Integer indexCounter = 1;
						conditionsSection.addTableHeaders(new List<String>{null, PB_TABLE_LABEL_FIELD, PB_TABLE_LABEL_OPERATOR, PB_TABLE_LABEL_TYPE, PB_TABLE_LABEL_VALUE});

						for(MetadataService.FlowRecordFilter frf : recordLookup.filters) {
							List<SideBarTableRow> rowObjects = new List<SideBarTableRow>();
							rowObjects.add(new SideBarTableRow(String.valueOf(indexCounter++)));
							rowObjects.add(new SideBarTableRow(String.valueOf(getProcessMetadataValue(PB_META_KEY_LEFT_HAND_SIDE_LABEL, frf.processMetadataValues))));
							rowObjects.add(new SideBarTableRow(OPERATORS_MAP.get(frf.operator)));
							rowObjects.add(new SideBarTableRow(String.valueOf(getProcessMetadataValue(PB_META_KEY_RIGHT_HAND_SIDE_TYPE, frf.processMetadataValues))));
							rowObjects.add(new SideBarTableRow(getFlowElementReferenceOrValue(frf.value)));
							conditionsSection.addTableRows(rowObjects);
						}
						this.sections.add(conditionsSection);
					}
				}
			}
			// started from Record change
			else {
				SideBarSection objectSection = new SideBarSection(PB_LABEL_OBJECT, SideBarItemType.TEXT)
					.addText(this.objectType);

				SideBarSection howStartSection = new SideBarSection(PB_LABEL_START_THE_PROCESS, SideBarItemType.RADIOBUTTON)
					.addRadioButton(this.triggerType == PK_KEY_TRIGGER_TYPE_INSERT, PB_LABEL_TRIGGER_TYPE_INSERT)
					.addRadioButton(this.triggerType == PK_KEY_TRIGGER_TYPE_UPDATE, PB_LABEL_TRIGGER_TYPE_UPDATE);

				String recursionValue = String.valueOf(getProcessMetadataValue(PB_META_KEY_RECURSIVE_COUNT_VARIABLE, sfdcFlow.processMetadataValues));
				SideBarSection recursionSection = new SideBarSection(PB_LABEL_RECURSION_RPOCESS, SideBarItemType.CHECKBOX)
					.addCheckBox(recursionValue != 'null', PB_LABEL_YES);

				this.sections.add(objectSection);
				this.sections.add(howStartSection);
				this.sections.add(recursionSection);

			}
		}
	}

	public static Map<String, String> getUserMaps(List<String> userIds) {
		return getUserOrGroupMaps('User', userIds);
	}

	public static Map<String, String> getGroupMaps(List<String> groupIds) {
		return getUserOrGroupMaps('CollaborationGroup', groupIds);
	}

	public static Map<String, String> getUserOrGroupMaps(String objectName, List<String> recordIds) {
		Map<String, String> result = new Map<String, String>();
		String query = new QBuilder(objectName)
			.selectFields(new Set<String>{'Id', 'Name'})
			.add(QBuilder.condition('Id').isIn(recordIds))
			.buildToolingQuery();
		String b = HttpUtils.get(
			StackTraceParser.corg.Instance_Url__c + ConfigUtil.TOOLING_QUERY_PATH + query,
			StackTraceParser.getHeaders(),
				200
		);

		Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(b);
		List<Object> recordList = (List<Object>)results.get('records');
		for(Object recordItem : recordList) {
			Map<String, Object> mapRecord = (Map<String, Object>)recordItem;
			String name = (String)mapRecord.get('Name');
			String id = (String)mapRecord.get('Id');
			result.put(id, name);
		}

		return result;
	}


	// Flow parser
	public static final String FLOW_CURRENT_SUPPORTED_API_VERSION = '50.0';
	public static final String FLOW_CONDITION_EMPTY = '';
	public static final String FLOW_CONDITION_EMPTY_LABEL = 'None—Get All Contact Records';
	public static final String FLOW_CONDITION_PAUSE_LABEL = 'Always Pause Flow—No Conditions';
	public static final String FLOW_CONDITION_OR = 'OR';
	public static final String FLOW_CONDITION_OR_LABEL = 'Any Condition Is Met (OR)';
	public static final String FLOW_CONDITION_AND = 'AND';
	public static final String FLOW_CONDITION_AND_LABEL = 'All Conditions Are Met (AND)';
	public static final String FLOW_CONDITION_CUSTOM_LABEL = 'Custom Condition Logic Is Met';
	// CS_Problem_Category_Level1__c = {!varGeneralIssueCategory} (General Inquiry)

	public static final Pattern SYSTEM_RUN_TIME_VALUE = Pattern.compile('Value at run time\\s?:\\s?(.*)$');

	public static Flow parseFlowStackTrace(String htmlStackTrace) {
		Flow result = null;

		Dom.XmlNode[] rootElements = getRootElementsFromHtml(htmlStackTrace);

		String flowAPIName = getProcessBuilderApiName(rootElements);

		if(String.isNotBlank(flowAPIName)) {
			result = getSFDCFlow(flowAPIName);

			String firstNodeError;
			String blockName;
			String childsBlockLines;
			String previousBlock;
			Integer edgeIndex = 2;

			for(Dom.XmlNode xmlNode : rootElements) {
				Dom.XmlNodeType nodeType = xmlNode.getNodeType();

				switch on nodeType {
					when TEXT {}
					when ELEMENT {
						if(xmlNode.getName() == HTML_TAG_PARAGRAPH && firstNodeError == null) {
							firstNodeError = xmlNode.getText();
						}
						Dom.XmlNode[] elementNodes = xmlNode.getChildren();
						for(Dom.XmlNode childXmlNode : elementNodes) {
							Dom.XmlNodeType childNodeType = childXmlNode.getNodeType();
							switch on childNodeType {
								when ELEMENT {
									if(childXmlNode.getName() == HTML_TAG_SPAN) {
										blockName = childXmlNode.getText();
									}
								}
								when TEXT {
									if(blockName != null) {
										childsBlockLines = childXmlNode.getText();
										List<String> lines = childsBlockLines.split(PB_STACK_TRACE_EOL);

										Map<String, Object> myVariable = getContextVariables(lines, (Map<String, Object>)result.context.get(PB_ST_COMMON_VAR_NAME));
										result.context.put(PB_ST_COMMON_VAR_NAME, myVariable);

										if(blockName == PB_ST_FLOW_DETAILS) {
											result.context.put(PB_ST_VAR_FLOW_API_NAME_NAME, getLineValue(lines, PB_ST_VAR_FLOW_API_NAME_LABEL));
											result.context.put(PB_ST_VAR_TYPE_NAME, getLineValue(lines, PB_ST_VAR_TYPE_LABEL));
											result.context.put(PB_ST_VAR_VERSION_NAME, getLineValue(lines, PB_ST_VAR_VERSION_LABEL));
											result.context.put(PB_ST_VAR_STATUS_NAME, getLineValue(lines, PB_ST_VAR_STATUS_LABEL));
											result.context.put(PB_ST_VAR_ORG_NAME, getLineValue(lines, PB_ST_VAR_ORG_LABEL));
										}
										else if(blockName == PB_ST_FLOW_INTERVIEW_DETAILS) {
											result.context.put(PB_ST_VAR_CURRENT_USER_NAME, getLineValue(lines, PB_ST_VAR_CURRENT_USER_LABEL));
											result.context.put(PB_ST_VAR_START_TIME_NAME, getLineValue(lines, PB_ST_VAR_START_TIME_LABEL));
										}
										else if(blockName == PB_ST_HOW_START) {
											result.context.put(PB_ST_VAR_RUN_API_NAME, getLineValue(lines, PB_ST_VAR_RUN_API_LABEL));
										}
										else {
											String elementAPIName = lines.get(0);
											List<String> resultLines = new List<String>();
											if(blockName == 'Result') {
												for(String l : lines) {
													if(String.isNotBlank(l)) {
														resultLines.add(l);
													}
												}
											}
											if(!result.elements.containsKey(elementAPIName) && String.isNotBlank(previousBlock)) {
												for(FlowElement fe : result.elements.values()) {
													if(fe.name == previousBlock) {
														fe.context.put('Result', resultLines);
													}
												}
											}

											for(FlowElement fe : result.elements.values()) {
												if(fe.name == elementAPIName || (!fe.executed && fe.label == elementAPIName)) {
													fe.executed = true;

													if(fe.actionType == 'FlowLoop') {
														String loopArrayString = getLineValue(lines, 'Loop Through');
														if(String.isNotBlank(loopArrayString)) {
															fe.context.put('LoopArray', loopArrayString.removeStart('[').removeEnd(']').split('\\,'));
														}
														String currentItem = getLineValue(lines, 'Current iteration item');
														if(String.isNotBlank(currentItem)) {
															fe.context.put('CurrentIterationItem', currentItem);
														}

														String iteration = getLineValue(lines, 'Iteration');
														if(String.isNotBlank(iteration)) {
															fe.context.put('Iteration', iteration);
														}
													}
													if(previousBlock != null) {
														List<FlowEdge> edges = result.edges.get(previousBlock) != null
															? new List<FlowEdge>(result.edges.get(previousBlock))
															: new List<FlowEdge>();

														for(FlowEdge edge : edges) {
															if(edge.target == fe.name) {
																edge.addIndex(edgeIndex++);
															}
														}
														result.edges.put(previousBlock, new Set<FlowEdge>(edges));
													}
													previousBlock = fe.name;
													break;
												}
											}
										}
										blockName = null;
									}
									else if(childXmlNode.getText().contains('Error Occurred:')) {
										result.errorMessage = childXmlNode.getText();
									}
								}
							}
						}
					}
				}
			}
			try {
				result.apexStackTraceParseResults = StackTraceParser.parseStackTrace(result.errorMessage);
			}
			catch(Exception e) {}
		}
		return result;
	}

	public static Flow getSFDCFlow(String flowApiName) {
		Flow result = new Flow();

		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.setEndpointAndMetadataAPIVersion(StackTraceParser.corg.Instance_Url__c, FLOW_CURRENT_SUPPORTED_API_VERSION);
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = ConnectedOrgService.getConnectedOrgAccessToken(StackTraceParser.corg);

		MetadataService.Flow sfdcFlow =
			(MetadataService.Flow) service.readMetadata('Flow',
				new String[] {flowApiName}).getRecords()[0];

		if(sfdcFlow != null && sfdcFlow.fullName != null) {
			result.name = sfdcFlow.fullName;
			result.label = sfdcFlow.label;
			result.processType = sfdcFlow.processType;
			result.start = new FlowStart(sfdcFlow.processType, sfdcFlow);
			getFlowElements(result, sfdcFlow, result.start.startRefference);
		}
		return result;
	}

	public static void getFlowElements(Flow flow, MetadataService.Flow sfdcFlow, String nextRefferenceName) {
		if(String.isNotBlank(nextRefferenceName) && !flow.edges.containsKey(nextRefferenceName)) {

			if(sfdcFlow.waits != null) {
				for(MetadataService.FlowWait flowWait : sfdcFlow.waits) {
					if(nextRefferenceName == flowWait.name) {
						FlowElement fe = new FlowElement(flowWait.name, flowWait.label, 'FlowWait', flowWait.locationX, flowWait.locationY);
						fe.setIcon('wait');
						addFlowWaitInfo(fe, flowWait);
						flow.elements.put(flowWait.name, fe);
						if(flowWait.defaultConnector != null && flowWait.defaultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, flowWait.defaultConnector.targetReference);
							getFlowElements(flow,  sfdcFlow, flowWait.defaultConnector.targetReference);
						}
						if(flowWait.faultConnector != null && flowWait.faultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, flowWait.faultConnector.targetReference, 'Fault', true);
							getFlowElements(flow,  sfdcFlow, flowWait.faultConnector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.subflows != null) {
				for(MetadataService.FlowSubflow subFlow : sfdcFlow.subflows) {
					if(nextRefferenceName == subFlow.name) {
						FlowElement fe = new FlowElement(subFlow.name, subFlow.label, 'FlowSubflow', subFlow.locationX, subFlow.locationY);
						fe.setIcon('sub_flow');
						addSubFlowInfo(fe, subFlow);
						flow.elements.put(subFlow.name, fe);
						if(subFlow.connector != null && subFlow.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, subFlow.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, subFlow.connector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.loops != null) {
				for(MetadataService.FlowLoop flowLoop : sfdcFlow.loops) {
					if(nextRefferenceName == flowLoop.name) {
						FlowElement fe = new FlowElement(flowLoop.name, flowLoop.label, 'FlowLoop', flowLoop.locationX, flowLoop.locationY);
						fe.setIcon('loop');
						addFlowLoopInfo(fe, flowLoop);
						flow.elements.put(flowLoop.name, fe);
						if(flowLoop.nextValueConnector != null && flowLoop.nextValueConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, flowLoop.nextValueConnector.targetReference, 'For Each Item');
							getFlowElements(flow,  sfdcFlow, flowLoop.nextValueConnector.targetReference);
						}
						if(flowLoop.noMoreValuesConnector != null && flowLoop.noMoreValuesConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, flowLoop.noMoreValuesConnector.targetReference, 'After Last Item');
							getFlowElements(flow,  sfdcFlow, flowLoop.noMoreValuesConnector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.assignments != null) {
				for(MetadataService.FlowAssignment fa : sfdcFlow.assignments) {
					if(nextRefferenceName == fa.name) {
						FlowElement fe = new FlowElement(fa.name, fa.label, 'FlowAssignment', fa.locationX, fa.locationY);
						fe.setIcon('assignment');
						addAssignmentInfo(fe, fa);
						flow.elements.put(fa.name, fe);

						if(fa.connector != null && fa.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fa.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fa.connector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.decisions != null) {
				for(MetadataService.FlowDecision fd : sfdcFlow.decisions) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowDecision', fd.locationX, fd.locationY);
						fe.setIcon('decision');
						addDecisionInfo(fe, fd);
						flow.elements.put(fe.name, fe);
						if(fd.defaultConnector != null && fd.defaultConnector.targetReference != null) {
							String edgeLabel = fd.defaultConnectorLabel;
							flow.addEdge(nextRefferenceName, fd.defaultConnector.targetReference, edgeLabel);
							getFlowElements(flow,  sfdcFlow, fd.defaultConnector.targetReference);
						}
						if(fd.rules != null) {
							for(MetadataService.FlowRule fdr : fd.rules) {
								if(fdr.connector != null && fdr.connector.targetReference != null) {
									String edgeLabel = fdr.label;
									flow.addEdge(nextRefferenceName, fdr.connector.targetReference, edgeLabel);
									getFlowElements(flow,  sfdcFlow, fdr.connector.targetReference);
								}
							}
						}
					}
				}
			}

			if(sfdcFlow.recordCreates != null) {
				for(MetadataService.FlowRecordCreate fd : sfdcFlow.recordCreates) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowRecordCreate', fd.locationX, fd.locationY);
						fe.setIcon('record_create');
						addRecordsCreateInfo(fe, fd, sfdcFlow);
						flow.elements.put(fe.name, fe);
						if(fd.connector != null && fd.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fd.connector.targetReference);
						}
						if(fd.faultConnector != null && fd.faultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.faultConnector.targetReference, 'Fault', true);
							getFlowElements(flow,  sfdcFlow, fd.faultConnector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.recordUpdates != null) {
				for(MetadataService.FlowRecordUpdate fd : sfdcFlow.recordUpdates) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowRecordUpdate', fd.locationX, fd.locationY);
						fe.setIcon('record_update');
						addRecordsUpdateInfo(fe, fd);
						flow.elements.put(fe.name, fe);
						if(fd.connector != null && fd.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fd.connector.targetReference);
						}
						if(fd.faultConnector != null && fd.faultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.faultConnector.targetReference, 'Fault', true);
							getFlowElements(flow,  sfdcFlow, fd.faultConnector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.recordLookups != null) {
				for(MetadataService.FlowRecordLookup fd : sfdcFlow.recordLookups) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowRecordLookup', fd.locationX, fd.locationY);
						fe.setIcon('record_lookup');
						addRecordsLookupInfo(fe, fd);
						flow.elements.put(fe.name, fe);
						if(fd.connector != null && fd.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fd.connector.targetReference);
						}
						if(fd.faultConnector != null && fd.faultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.faultConnector.targetReference, 'Fault', true);
							getFlowElements(flow,  sfdcFlow, fd.faultConnector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.recordDeletes != null) {
				for(MetadataService.FlowRecordDelete fd : sfdcFlow.recordDeletes) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowRecordDelete', fd.locationX, fd.locationY);
						fe.setIcon('record_delete');
						addRecordsDeleteInfo(fe, fd);
						flow.elements.put(fe.name, fe);
						if(fd.connector != null && fd.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fd.connector.targetReference);
						}
						if(fd.faultConnector != null && fd.faultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.faultConnector.targetReference, 'Fault', true);
							getFlowElements(flow,  sfdcFlow, fd.faultConnector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.screens != null) {
				for(MetadataService.FlowScreen fd : sfdcFlow.screens) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowScreen', fd.locationX, fd.locationY);
						fe.setIcon('screen');
						addScreenInfo(fe, fd);
						flow.elements.put(fe.name, fe);
						if(fd.connector != null && fd.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fd.connector.targetReference);
						}
					}
				}
			}

			if(sfdcFlow.actionCalls != null) {
				for(MetadataService.FlowActionCall fd : sfdcFlow.actionCalls) {
					if(nextRefferenceName == fd.name) {
						FlowElement fe = new FlowElement(fd.name, fd.label, 'FlowActionCall', fd.locationX, fd.locationY);
						fe.setIcon('action');
						addFlowActionInfo(fe, fd);
						flow.elements.put(fe.name, fe);
						if(fd.connector != null && fd.connector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.connector.targetReference);
							getFlowElements(flow,  sfdcFlow, fd.connector.targetReference);
						}
						if(fd.faultConnector != null && fd.faultConnector.targetReference != null) {
							flow.addEdge(nextRefferenceName, fd.faultConnector.targetReference, 'Fault', true);
							getFlowElements(flow,  sfdcFlow, fd.faultConnector.targetReference);
						}
					}
				}
			}
		}
	}

	public class FlowRecordDeleteInfo {
		public String label;
		public String name;
		public String objectName;
		public String inputReference;
		public Boolean useTheIDsStored;
		public Boolean specifyConditions;

		public String conditionLogic;
		public String conditionName;
		public String conditionLabel;
		public List<FlowRecordFilterInfo> conditions;

		public FlowRecordDeleteInfo(String label, String name) {
			this.label = label;
			this.name = name;
			this.conditions = new List<FlowRecordFilterInfo>();
		}
	}

	public static void addRecordsDeleteInfo(FlowElement element, MetadataService.FlowRecordDelete flowRecordDelete) {
		FlowRecordDeleteInfo result = new FlowRecordDeleteInfo(flowRecordDelete.label, flowRecordDelete.name);
		result.inputReference = flowRecordDelete.inputReference;
		result.objectName = flowRecordDelete.object_x;

		if(flowRecordDelete.filters != null) {
			for(MetadataService.FlowRecordFilter filter : flowRecordDelete.filters) {
				result.conditions.add(new FlowRecordFilterInfo(
					filter.field,
					filter.operator,
					String.valueOf(getFlowElementReferenceOrValue(filter.value))
				));
			}
			result.conditionLogic = flowRecordDelete.filterLogic;
			if(result.conditionLogic == null) {
				result.conditionLabel = FLOW_CONDITION_EMPTY_LABEL;
				result.conditionName = FLOW_CONDITION_EMPTY;
			}
			else if(result.conditionLogic == 'and') {
				result.conditionLabel = FLOW_CONDITION_AND_LABEL;
				result.conditionName = FLOW_CONDITION_AND;
			}
			else if(result.conditionLogic == 'or') {
				result.conditionLabel = FLOW_CONDITION_OR_LABEL;
				result.conditionName = FLOW_CONDITION_OR;
			}
			else {
				result.conditionLabel = FLOW_CONDITION_CUSTOM_LABEL;
				result.conditionName = flowRecordDelete.filterLogic;
				result.conditionLogic = flowRecordDelete.filterLogic;
			}
		}
		result.specifyConditions = (!result.conditions.isEmpty());
		result.useTheIDsStored = !result.specifyConditions;

		element.metadataInfo = result;
	}


	public class FlowSubFlowInfo {
		public String label;
		public String name;
		public String flowName;
		public Boolean manuallyAssignVariables;
		public List<FlowSubflowInputAssignmentInfo> inputAssignments;
		public List<FlowSubflowOutputAssignmentInfo> outputAssignments;

		public FlowSubFlowInfo(String label, String name, String flowName) {
			this.label = label;
			this.name = name;
			this.flowName = flowName;
			this.inputAssignments = new List<FlowSubflowInputAssignmentInfo>();
			this.outputAssignments = new List<FlowSubflowOutputAssignmentInfo>();
		}
	}

	public class FlowSubflowInputAssignmentInfo {
		public String name;
		public Object value;

		public FlowSubflowInputAssignmentInfo(String name, Object value) {
			this.name = name;
			this.value = value;
		}
	}

	public class FlowSubflowOutputAssignmentInfo {
		public String name;
		public String assignToReference;

		public FlowSubflowOutputAssignmentInfo(String name, String assignToReference) {
			this.name = name;
			this.assignToReference = assignToReference;
		}
	}

	public static void addSubFlowInfo(FlowElement element, MetadataService.FlowSubflow subFlow) {
		FlowSubFlowInfo result = new FlowSubFlowInfo(subFlow.label, subFlow.name, subFlow.flowName);
		if(subFlow.inputAssignments != null) {
			for(MetadataService.FlowSubflowInputAssignment ia : subFlow.inputAssignments) {
				result.inputAssignments.add(new FlowSubflowInputAssignmentInfo(
					ia.name,
					String.valueOf(getFlowElementReferenceOrValue(ia.value))
				));
			}
		}
		if(subflow.outputAssignments != null) {
			for(MetadataService.FlowSubflowOutputAssignment ia : subFlow.outputAssignments) {
				result.outputAssignments.add(new FlowSubflowOutputAssignmentInfo(
					ia.name,
					ia.assignToReference
				));
			}
			result.manuallyAssignVariables = !result.outputAssignments.isEmpty();
		}
		element.metadataInfo = result;
	}

	public class FlowWaitInfo {
		public String label;
		public String name;
		public List<FlowWaitEventInfo> events;
		public String defaultConnectorLabel;

		public FlowWaitInfo(String label, String name) {
			this.label = label;
			this.name = name;
			this.events = new List<FlowWaitEventInfo>();
		}
	}

	public class FlowWaitEventInfo {

		public String name;
		public String label;
		public String eventType;
		public String conditionLogic;
		public String conditionName;
		public String conditionLabel;

		public List<FlowWaitEventConditionInfo> conditions;
		public List<FlowWaitEventInputParameterInfo> inputParameters;
		public List<FlowWaitEventOutputParameterInfo> outputParameters;

		public FlowWaitEventInfo(String label, String name, String eventType){
			this.name = name;
			this.label = label;
			this.eventType = eventType;
			this.conditions = new List<FlowWaitEventConditionInfo>();
			this.inputParameters = new List<FlowWaitEventInputParameterInfo>();
			this.outputParameters = new List<FlowWaitEventOutputParameterInfo>();
		}
	}

	public class FlowWaitEventConditionInfo {
		public String resource;
		public String operator;
		public Object value;

		public FlowWaitEventConditionInfo(String resource, String operator, Object value) {
			this.resource = resource;
			this.operator = operator;
			this.value = value;
		}
	}

	public class FlowWaitEventInputParameterInfo {
		public String name;
		public String value;

		public FlowWaitEventInputParameterInfo(String name, String value) {
			this.name = name;
			this.value = value;
		}
	}

	public class FlowWaitEventOutputParameterInfo {
		public String name;
		public String assignToReference;

		public FlowWaitEventOutputParameterInfo(String name, String assignToReference) {
			this.name = name;
			this.assignToReference = assignToReference;
		}
	}

	public static void addFlowWaitInfo(FlowElement element, MetadataService.FlowWait flowWait) {
		FlowWaitInfo result = new FlowWaitInfo(flowWait.label, flowWait.name);
		result.defaultConnectorLabel = flowWait.defaultConnectorLabel;

		if(flowWait.waitEvents != null) {
			for(MetadataService.FlowWaitEvent fwe : flowWait.waitEvents) {
				FlowWaitEventInfo fwEventInfo = new FlowWaitEventInfo(fwe.label, fwe.name, fwe.eventType);

				if(fwe.conditions != null) {
					fwEventInfo.conditionLogic = fwe.conditionLogic;
					if(fwEventInfo.conditionLogic == null) {
						fwEventInfo.conditionLabel = FLOW_CONDITION_PAUSE_LABEL;
						fwEventInfo.conditionName = FLOW_CONDITION_EMPTY;
					}
					else if(fwEventInfo.conditionLogic == 'and') {
						fwEventInfo.conditionLabel = FLOW_CONDITION_AND_LABEL;
						fwEventInfo.conditionName = FLOW_CONDITION_AND;
					}
					else if(fwEventInfo.conditionLogic == 'or') {
						fwEventInfo.conditionLabel = FLOW_CONDITION_OR_LABEL;
						fwEventInfo.conditionName = FLOW_CONDITION_OR;
					}
					else {
						fwEventInfo.conditionLabel = FLOW_CONDITION_CUSTOM_LABEL;
						fwEventInfo.conditionName = fwe.conditionLogic;
						fwEventInfo.conditionLogic = fwe.conditionLogic;
					}

					for(MetadataService.FlowCondition condition : fwe.conditions) {
						fwEventInfo.conditions.add(new FlowWaitEventConditionInfo(
							condition.leftValueReference,
							condition.operator,
							String.valueOf(getFlowElementReferenceOrValue(condition.rightValue))
						));
					}
				}

				if(fwe.inputParameters != null) {
					for(MetadataService.FlowWaitEventInputParameter ip : fwe.inputParameters) {
						fwEventInfo.inputParameters.add(new FlowWaitEventInputParameterInfo(
							ip.name,
							String.valueOf(getFlowElementReferenceOrValue(ip.value))
						));
					}
				}
				if(fwe.outputParameters != null) {
					for(MetadataService.FlowWaitEventOutputParameter ip : fwe.outputParameters) {
						fwEventInfo.outputParameters.add(new FlowWaitEventOutputParameterInfo(
							ip.name,
							ip.assignToReference
						));
					}
				}
				result.events.add(fwEventInfo);
			}
		}

		element.metadataInfo = result;
	}

	public class FlowLoopInfo {
		public String label;
		public String name;
		public String collectionVariable;
		public String iterationDirection;
		public Boolean firstItemToLastItem;
		public Boolean lastItemToFirstItem;
		public String loopVariable;

		public FlowLoopInfo(String label, String name) {
			this.label = label;
			this.name = name;
		}
	}

	public static void addFlowLoopInfo(FlowElement element, MetadataService.FlowLoop flowLoop) {
		FlowLoopInfo result = new FlowLoopInfo(flowLoop.label, flowLoop.name);
		result.collectionVariable = flowLoop.collectionReference;
		result.loopVariable = flowLoop.assignNextValueToReference;
		result.iterationDirection = flowLoop.iterationOrder;
		result.firstItemToLastItem = 'Asc' == result.iterationDirection;
		result.lastItemToFirstItem = !result.firstItemToLastItem;
		element.metadataInfo = result;
	}


	public class FlowActionInfo {
		public String label;
		public String name;
		public String actionName;
		public String actionType;
		public List<FlowActionCallInputParameterInfo> assignments;

		public FlowActionInfo(String label, String name, String actionName, String actionType) {
			this.label = label;
			this.name = name;
			this.actionName = actionName;
			this.actionType = actionType;
			this.assignments = new List<FlowActionCallInputParameterInfo>();
		}
	}

	public class FlowActionCallInputParameterInfo {
		public String name;
		public Object value;

		public FlowActionCallInputParameterInfo(String name, Object value) {
			this.name = name;
			this.value = value;
		}
	}

	public static void addFlowActionInfo(FlowElement element, MetadataService.FlowActionCall flowAction) {
		FlowActionInfo result = new FlowActionInfo(flowAction.label, flowAction.name, flowAction.actionName, flowAction.actionType);
		if(flowAction.inputParameters != null) {
			for(MetadataService.FlowActionCallInputParameter ia : flowAction.inputParameters) {
				result.assignments.add(new FlowActionCallInputParameterInfo(
					ia.name,
					String.valueOf(getFlowElementReferenceOrValue(ia.value))
				));
			}
		}
		element.metadataInfo = result;
	}



	public class FlowRecordUpdateInfo {
		public String label;
		public String name;
		public String objectName;

		public Boolean specifyConditionsToIdentifyRecords;
		public Boolean useTheIDs;
		public String inputReference;

		public String conditionLogic;
		public String conditionLabel;
		public String conditionName;
		public List<FlowRecordFilterInfo> conditions;
		public List<FlowInputFieldAssignmentInfo> assignments;


		public FlowRecordUpdateInfo(String label, String name, String objectName) {
			this.label = label;
			this.name = name;
			this.objectName = objectName;
			this.conditions = new List<FlowRecordFilterInfo>();
			this.assignments = new List<FlowInputFieldAssignmentInfo>();
		}
	}

	public static void addRecordsUpdateInfo(FlowElement element, MetadataService.FlowRecordUpdate flowRecordUpdate) {
		FlowRecordUpdateInfo result = new FlowRecordUpdateInfo(flowRecordUpdate.label, flowRecordUpdate.name, flowRecordUpdate.object_x);
		result.objectName = flowRecordUpdate.object_x;

		if(flowRecordUpdate.filters != null) {
			for(MetadataService.FlowRecordFilter filter : flowRecordUpdate.filters) {
				result.conditions.add(new FlowRecordFilterInfo(
					filter.field,
					filter.operator,
					String.valueOf(getFlowElementReferenceOrValue(filter.value))
				));
			}
			result.conditionLogic = flowRecordUpdate.filterLogic;
			if(result.conditionLogic == null) {
				result.conditionLabel = FLOW_CONDITION_EMPTY_LABEL;
				result.conditionName = FLOW_CONDITION_EMPTY;
			}
			else if(result.conditionLogic == 'and') {
				result.conditionLabel = FLOW_CONDITION_AND_LABEL;
				result.conditionName = FLOW_CONDITION_AND;
			}
			else if(result.conditionLogic == 'or') {
				result.conditionLabel = FLOW_CONDITION_OR_LABEL;
				result.conditionName = FLOW_CONDITION_OR;
			}
			else {
				result.conditionLabel = FLOW_CONDITION_CUSTOM_LABEL;
				result.conditionName = flowRecordUpdate.filterLogic;
				result.conditionLogic = flowRecordUpdate.filterLogic;
			}
		}

		if(flowRecordUpdate.inputAssignments != null) {
			for(MetadataService.FlowInputFieldAssignment inputFieldAssignment : flowRecordUpdate.inputAssignments) {
				result.assignments.add(new FlowInputFieldAssignmentInfo(
					inputFieldAssignment.field,
					String.valueOf(getFlowElementReferenceOrValue(inputFieldAssignment.value))
				));
			}
		}

		result.specifyConditionsToIdentifyRecords = (!result.assignments.isEmpty());
		result.useTheIDs = !result.specifyConditionsToIdentifyRecords;
		if(result.useTheIDs) {
			result.inputReference = flowRecordUpdate.inputReference;
		}

		element.metadataInfo = result;
	}

	public class FlowRecordCreateInfo {
		public String label;
		public String name;
		public String objectName;
		public List<FlowInputFieldAssignmentInfo> assignments;

		public Boolean oneRecordsCreate;
		public Boolean multipleRecordsCreate;
		public Boolean useAllValuesFromRecord;
		public Boolean useSeparateResources;
		public Boolean manuallyAssignVariables;

		public String assignRecordIdToReference;
		public String inputReference;


		public FlowRecordCreateInfo(String label, String name, String objectName) {
			this.label = label;
			this.name = name;
			this.objectName = objectName;
			this.assignments = new List<FlowInputFieldAssignmentInfo>();
		}
	}

	public class FlowInputFieldAssignmentInfo {
		public String field;
		public Object value;

		public FlowInputFieldAssignmentInfo(String field, Object value) {
			this.field = field;
			this.value = value;
		}
	}

	public static void addRecordsCreateInfo(FlowElement element, MetadataService.FlowRecordCreate flowRecordCreate, MetadataService.Flow sfdcFlow) {
		FlowRecordCreateInfo result = new FlowRecordCreateInfo(flowRecordCreate.label, flowRecordCreate.name, flowRecordCreate.object_x);

		if(flowRecordCreate.inputAssignments != null) {
			for(MetadataService.FlowInputFieldAssignment ia : flowRecordCreate.inputAssignments) {
				result.assignments.add(new FlowInputFieldAssignmentInfo(
					ia.field,
					String.valueOf(getFlowElementReferenceOrValue(ia.value))
				));
			}
			if(!flowRecordCreate.inputAssignments.isEmpty()) {
				result.oneRecordsCreate = true;
			}
		}
		if(String.isNotBlank(flowRecordCreate.assignRecordIdToReference)) {
			result.manuallyAssignVariables = true;
			result.assignRecordIdToReference = flowRecordCreate.assignRecordIdToReference;
		}
		if(String.isNotBlank(flowRecordCreate.inputReference)) {
			result.useAllValuesFromRecord = true;
			result.inputReference = flowRecordCreate.inputReference;

			MetadataService.FlowVariable flowVariable = getFlowVariable(flowRecordCreate.inputReference, sfdcFlow);
			if(flowVariable != null && flowVariable.isCollection) {
				result.multipleRecordsCreate = true;
			}
			else if(flowVariable != null && !flowVariable.isCollection) {
				result.oneRecordsCreate = true;
			}
		}

		element.metadataInfo = result;
	}

	public class FlowRecordLookupInfo {
		public String label;
		public String apiName;
		public String objectName;
		public String conditionLogic;
		public String conditionLabel;
		public String conditionName;
		public List<FlowRecordFilterInfo> conditions;
		public List<FlowOutputFieldAssignmentInfo> assignments;
		public String sortOrder;
		public String sortBy;

		public Boolean onlyFirstRecord;
		public Boolean allRecords;
		public Boolean storeAllFields;
		public Boolean chooseFieldsAndLetSalesforceDoTheRest;
		public Boolean chooseFieldsAndAssignVariables;
		public String storeVariable;
		public Boolean storeTogether;
		public Boolean storeSeparateVariables;
		public Boolean noRecordsAreReturned;

		public List<String> queriedFields;

		public  FlowRecordLookupInfo() {
			this.conditions = new List<FlowRecordFilterInfo>();
			this.assignments = new List<FlowOutputFieldAssignmentInfo>();
			this.queriedFields = new List<String>();
		}

	}

	public class FlowRecordFilterInfo {
		public String field;
		public String operator;
		public Object value;

		public FlowRecordFilterInfo(String field, String operator, Object value){
			this.field = field;
			this.operator = operator;
			this.value = value;
		}
	}

	public class FlowOutputFieldAssignmentInfo {
		public String field;
		public String variable;

		public FlowOutputFieldAssignmentInfo(String field, String variable) {
			this.field = field;
			this.variable = variable;
		}
	}

	public static void addRecordsLookupInfo(FlowElement element, MetadataService.FlowRecordLookup flowRecordLookup) {
		FlowRecordLookupInfo result = new FlowRecordLookupInfo();
		result.label = flowRecordLookup.label;
		result.apiName = flowRecordLookup.name;
		result.objectName = flowRecordLookup.object_x;

		result.onlyFirstRecord = flowRecordLookup.getFirstRecordOnly == true;
		result.allRecords = !result.onlyFirstRecord;
		result.storeAllFields = true;



		if(String.isNotBlank(flowRecordLookup.outputReference)) {
			result.storeVariable = flowRecordLookup.outputReference;
			result.noRecordsAreReturned = flowRecordLookup.assignNullValuesIfNoRecordsFound;

			if(flowRecordLookup.queriedFields != null) {
				for(String qField : flowRecordLookup.queriedFields) {
					result.queriedFields.add(qField);
				}
				result.chooseFieldsAndAssignVariables = !flowRecordLookup.queriedFields.isEmpty();
				result.storeAllFields = !result.chooseFieldsAndAssignVariables;
				result.storeTogether = true;
			}
		}
		else {
			if(flowRecordLookup.queriedFields != null) {
				for(String qField : flowRecordLookup.queriedFields) {
					result.queriedFields.add(qField);
				}
				result.chooseFieldsAndLetSalesforceDoTheRest = !flowRecordLookup.queriedFields.isEmpty();
				result.storeAllFields = !result.chooseFieldsAndLetSalesforceDoTheRest;
			}
		}

		if(flowRecordLookup.filters != null) {
			for(MetadataService.FlowRecordFilter filter : flowRecordLookup.filters) {
				result.conditions.add(new FlowRecordFilterInfo(
					filter.field,
					filter.operator,
					String.valueOf(getFlowElementReferenceOrValue(filter.value))
				));
			}

			result.conditionLogic = flowRecordLookup.filterLogic;
			if(result.conditionLogic == null) {
				result.conditionLabel = FLOW_CONDITION_EMPTY_LABEL;
				result.conditionName = FLOW_CONDITION_EMPTY;
			}
			else if(result.conditionLogic == 'and') {
				result.conditionLabel = FLOW_CONDITION_AND_LABEL;
				result.conditionName = FLOW_CONDITION_AND;
			}
			else if(result.conditionLogic == 'or') {
				result.conditionLabel = FLOW_CONDITION_OR_LABEL;
				result.conditionName = FLOW_CONDITION_OR;
			}
			else {
				result.conditionLabel = FLOW_CONDITION_CUSTOM_LABEL;
				result.conditionName = flowRecordLookup.filterLogic;
				result.conditionLogic = flowRecordLookup.filterLogic;
			}
		}
		result.sortOrder = flowRecordLookup.sortOrder;
		result.sortBy = flowRecordLookup.sortField;

		if(flowRecordLookup.outputAssignments != null) {
			for(MetadataService.FlowOutputFieldAssignment outputFieldAssignment : flowRecordLookup.outputAssignments) {
				result.assignments.add(new FlowOutputFieldAssignmentInfo(
					outputFieldAssignment.field,
					outputFieldAssignment.assignToReference
				));
			}

			result.chooseFieldsAndAssignVariables = !flowRecordLookup.outputAssignments.isEmpty();
			result.storeAllFields = !result.chooseFieldsAndAssignVariables;
			result.storeSeparateVariables = true;
		}

		element.metadataInfo = result;
	}

	public class FlowDecisionInfo {
		public String name;
		public String label;
		public List<FlowDecisionOutcomeInfo> outcomes;

		public FlowDecisionInfo(){
			this.outcomes = new List<FlowDecisionOutcomeInfo>();
		}

	}

	public class FlowDecisionOutcomeInfo {
		public String label;
		public String name;
		public String condition;
		public String conditionLogic;
		public String conditionName;
		public String conditionLabel;
		public List<FlowConditionInfo> conditions;

		public FlowDecisionOutcomeInfo(String label, String name) {
			this.label = label;
			this.name = name;
			this.conditions = new List<FlowConditionInfo>();
		}
	}

	public class FlowConditionInfo {
		public String resource;
		public String operator;
		public Object value;

		public FlowConditionInfo(String resource, String operator, Object value) {
			this.resource = resource;
			this.operator = operator;
			this.value = value;
		}
	}



	public static void addDecisionInfo(FlowElement element, MetadataService.FlowDecision flowDecision) {
		FlowDecisionInfo result = new FlowDecisionInfo();
		result.name = flowDecision.name;
		result.label = flowDecision.label;

		for(MetadataService.FlowRule rule : flowDecision.rules) {
			FlowDecisionOutcomeInfo fdo = new FlowDecisionOutcomeInfo(rule.label, rule.name);

			fdo.condition = rule.conditionLogic;
			if(rule.conditionLogic == null) {
				fdo.conditionLabel = FLOW_CONDITION_EMPTY_LABEL;
				fdo.conditionName = FLOW_CONDITION_EMPTY;
			}
			else if(rule.conditionLogic == 'and') {
				fdo.conditionLabel = FLOW_CONDITION_AND_LABEL;
				fdo.conditionName = FLOW_CONDITION_AND;
			}
			else if(rule.conditionLogic == 'or') {
				fdo.conditionLabel = FLOW_CONDITION_OR_LABEL;
				fdo.conditionName = FLOW_CONDITION_OR;
			}
			else {
				fdo.conditionLabel = FLOW_CONDITION_CUSTOM_LABEL;
				fdo.conditionName = rule.conditionLogic;
				fdo.conditionLogic = rule.conditionLogic;
			}

			for(MetadataService.FlowCondition fc : rule.conditions) {
				FlowConditionInfo fci = new FlowConditionInfo(
					fc.leftValueReference,
					fc.operator,
					String.valueOf(getFlowElementReferenceOrValue(fc.rightValue))
				);
				fdo.conditions.add(fci);
			}

			result.outcomes.add(fdo);
		}

		element.metadataInfo = result;
	}

	public class FlowScreenInfo {
		public String label;
		public String name;
		public Boolean showHeader;
		public Boolean showFooter;
		public Boolean nextOrFinish;
		public Boolean previous;
		public Boolean pause;
		public String helpText;

		public FlowScreenInfo(String label, String name) {
			this.label = label;
			this.name = name;
		}
	}

	public static void addScreenInfo(FlowElement element, MetadataService.FlowScreen flowScreen) {
		FlowScreenInfo result = new FlowScreenInfo(flowScreen.label, flowScreen.name);
		result.showHeader = flowScreen.showHeader;
		result.showFooter = flowScreen.showFooter;
		result.nextOrFinish = flowScreen.allowFinish;
		result.previous = flowScreen.allowBack;
		result.pause = flowScreen.allowPause;
		result.helpText = flowScreen.helpText;

		element.metadataInfo = result;
	}

	public class FlowAssignmentInfo {
		public String label;
		public String name;
		public List<FlowAssignmentsItemInfo> assignments;

		public FlowAssignmentInfo(String label, String name) {
			this.label = label;
			this.name = name;
			this.assignments = new List<FlowAssignmentsItemInfo>();
		}
	}

	public class FlowAssignmentsItemInfo {

		public String variable;
		public String operator;
		public Object value;

		public FlowAssignmentsItemInfo(String variable, String operator, Object value) {
			this.variable = variable;
			this.operator = operator;
			this.value = value;
		}
	}

	public static void addAssignmentInfo(FlowElement element, MetadataService.FlowAssignment flowAssignment) {
		FlowAssignmentInfo result = new FlowAssignmentInfo(flowAssignment.label, flowAssignment.name);

		if(flowAssignment.assignmentItems != null) {
			for(MetadataService.FlowAssignmentItem fai : flowAssignment.assignmentItems) {
				result.assignments.add(new FlowAssignmentsItemInfo(
					fai.assignToReference,
					fai.operator,
					String.valueOf(getFlowElementReferenceOrValue(fai.value))
				));
			}
		}
		element.metadataInfo = result;
	}

	public class Flow {
		public String name;
		public String label;
		public String processType;
		public FlowStart start;
		public Map<String, FlowElement> elements;
		public Map<String, Set<FlowEdge>> edges;
		public Map<String, Object> context;
		public List<StackTraceParser.StackTraceParseResult> apexStackTraceParseResults;
		public String errorMessage;

		public Flow() {
			this.elements = new Map<String, FlowElement>();
			this.edges = new Map<String, Set<FlowEdge>>();
			this.apexStackTraceParseResults = new List<StackTraceParser.StackTraceParseResult>();
			this.context = new Map<String, Object>();
		}

		public void addEdge(String startPath, String endPath) {
			addEdge(startPath, endPath, null);
		}

		public void addEdge(String startPath, String endPath, String edgeLabel, Boolean isFault) {
			Set<FlowEdge> edges = this.edges.get(startPath) != null ? this.edges.get(startPath) : new Set<FlowEdge>();
			FlowEdge fe = new FlowEdge(endPath, edgeLabel, isFault);
			edges.add(fe);
			this.edges.put(startPath, edges);
		}

		public void addEdge(String startPath, String endPath, String edgeLabel) {
			addEdge(startPath, endPath, edgeLabel, false);
		}
	}

	public class FlowEdge {
		public String label;
		public String target;
		public Boolean fault;
		public List<Integer> indexes;

		public FlowEdge(String target){
			this(target, null);
		}

		public FlowEdge(String target, String label){
			this(target, label, false);
		}

		public FlowEdge(String target, String label, Boolean isFault) {
			this.target = target;
			this.label = label;
			this.indexes = new List<Integer>();
			this.fault = isFault;
		}

		public void addIndex(Integer index) {
			this.indexes.add(index);
		}
	}

	public class FlowStart {
		public String startType;
		public String objectType;

		public Location location;
		public String startRefference;

		public Boolean aRecordIsCreated;
		public Boolean aRecordIsUpdated;
		public Boolean aRecordIsCreatedOrUpdated;
		public Boolean aRecordIsDeleted;
		public Boolean runFlowBeforeTheRecordIsSaved;
		public Boolean runFlowAfterTheRecordIsSaved;
		public Boolean runTheFlowEveryTime;
		public Boolean runTheFlowOnlyUpdate;

		public String recordTriggerType;
		public String triggerType;
		public String conditionLogic;
		public String conditionLabel;
		public String conditionName;
		public List<FlowRecordFilterInfo> conditions;

		public String scheduleFrequency;
		public String scheduleStartDate;
		public String scheduleStartTime;

		public FlowStart(String processType, MetadataService.Flow sfdcFlow) {
			this.triggerType = sfdcFlow.start.triggerType;
			this.location = new Location(sfdcFlow.start.locationX, sfdcFlow.start.locationY);
			this.objectType = sfdcFlow.start.object_x;
			if(sfdcFlow.start.connector != null && sfdcFlow.start.connector.targetReference != null) {
				this.startRefference = sfdcFlow.start.connector.targetReference;
			}

			this.runTheFlowOnlyUpdate = (sfdcFlow.start.doesRequireRecordChangedToMeetCriteria != null && sfdcFlow.start.doesRequireRecordChangedToMeetCriteria);
			this.runTheFlowEveryTime = !this.runTheFlowOnlyUpdate;
			this.recordTriggerType = sfdcFlow.start.recordTriggerType;
			this.aRecordIsCreated = (this.recordTriggerType == 'Create');
			this.aRecordIsUpdated = (this.recordTriggerType == 'Update');
			this.aRecordIsCreatedOrUpdated = (this.recordTriggerType == 'CreateAndUpdate');
			this.aRecordIsDeleted = (this.recordTriggerType == 'Delete');
			this.runFlowBeforeTheRecordIsSaved = (this.triggerType == 'RecordBeforeSave');
			this.runFlowAfterTheRecordIsSaved = (this.triggerType == 'RecordAfterSave');

			if(sfdcFlow.start.filters != null) {
				this.conditions = new List<FlowRecordFilterInfo>();
				for(MetadataService.FlowRecordFilter filter : sfdcFlow.start.filters) {
					this.conditions.add(new FlowRecordFilterInfo(
						filter.field,
						filter.operator,
						String.valueOf(getFlowElementReferenceOrValue(filter.value))
					));
				}
				this.conditionLogic = sfdcFlow.start.filterLogic;
				if(this.conditionLogic == null) {
					this.conditionLabel = FLOW_CONDITION_EMPTY_LABEL;
					this.conditionName = FLOW_CONDITION_EMPTY;
				}
				else if(this.conditionLogic == 'and') {
					this.conditionLabel = FLOW_CONDITION_AND_LABEL;
					this.conditionName = FLOW_CONDITION_AND;
				}
				else if(this.conditionLogic == 'or') {
					this.conditionLabel = FLOW_CONDITION_OR_LABEL;
					this.conditionName = FLOW_CONDITION_OR;
				}
				else {
					this.conditionLabel = FLOW_CONDITION_CUSTOM_LABEL;
					this.conditionName = sfdcFlow.start.filterLogic;
					this.conditionLogic = sfdcFlow.start.filterLogic;
				}
			}

			if(sfdcFlow.start.schedule != null) {
				this.scheduleFrequency = sfdcFlow.start.schedule.frequency;
				this.scheduleStartDate = sfdcFlow.start.schedule.startDate;
				this.scheduleStartTime = sfdcFlow.start.schedule.startTime;
			}
		}
	}

	public class Location {
		public Integer X;
		public Integer Y;

		public Location(Integer x, Integer y) {
			this.X = x;
			this.Y = y;
		}
	}

	public class FlowElement {
		public String name;
		public String label;
		public String actionType;
		public Boolean executed;
		public Map<String, Object> context;
		public String icon;
		public Location location;

		public Object metadataInfo;

		public FlowElement(String name, String label, String actionType, Integer locationX, Integer locationY) {
			this.name = name;
			this.label = label;
			this.actionType = actionType;
			this.executed = false;
			this.context = new Map<String, Object>();
			this.location = new Location(locationX, locationY);
		}

		public void setIcon(String icon) {
			this.icon = icon;
		}

	}
}