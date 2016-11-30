package com.m.pyramid.profile.controllers
{
	import com.m.pyramid.components.alerts.AlertUtil;
	import com.m.pyramid.components.alerts.ConfirmPopup;
	import com.m.pyramid.controls.MVCController;
	import com.m.pyramid.controls.MVCModel;
	import com.m.pyramid.model.AllowableCommand;
	import com.m.pyramid.model.ReferenceObject;
	import com.m.pyramid.model.SectorLeadAssignment;
	import com.m.pyramid.model.StateSectorLeadInfo;
	import com.m.pyramid.model.helpers.Message;
	import com.m.pyramid.model.helpers.ValidationResult;
	import com.m.pyramid.profile.StateSectorWrapper;
	import com.m.pyramid.profile.viewmodels.ManageSectorViewModel;
	import com.m.pyramid.profile.views.ManageSectorView;
	import com.m.pyramid.services.SectorLeadServiceProxy;
	import com.m.pyramid.services.SecurityUserServiceProxy;
	import com.m.pyramid.validation.ValidationPopup;

	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.utils.Dictionary;

	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.core.Application;
	import mx.managers.PopUpManager;
	import mx.rpc.Fault;

	public class ManageSectorController extends MVCController
	{


	    [Bindable]
	    public var view:ManageSectorView;
	    [Bindable]
	    public var model:ManageSectorViewModel = new ManageSectorViewModel();

	   // private var pageLoadingAlertModel:AlertsModel= new AlertsModel();

//        private function initializeAlertsModel():void
//        {
//        	pageLoadingAlertModel.cancelable = false;
//        	pageLoadingAlertModel.title ="Please wait";
//        	pageLoadingAlertModel.statusText="Working ...";
//        }
	    override public function openViewModel(viewModel:MVCModel):void
        {
        	var reset:Boolean = (this.model != viewModel );

        	if(this.hasOwnProperty("model"))
        	{
        		this["model"] = viewModel;

        	    if ( reset ) onSourceChange();
        	}
        }

		public function ManageSectorController()
		{
			//model = new ManageSectorViewModel();
		}
		public function onCreationComplete(e:Event = null):void
		{
		//	initializeAlertsModel();
			//MVCModel(this["model"]).closeFunction = onCloseClick;
			initEventListeners();
			initBindings();
			enableCommands();
			initControls();


			bindCloseFunction(onCloseClick);

		}
		public function onSourceChange(o:Object = null):void
		{
			model.populateNewModelFromView(view);
		//	openPageLoadingWindow();
			view.onSectorGridResize();
		}
		public function onExpandCollapse(event:Event):void
		{
			if (!event.currentTarget.selectedItem) return;

			var item:Object = event.currentTarget.selectedItem;
			switch (item.label)
			{
				case "Expand All":
					view.sectorGrid.expandAll();
					break;
				case "Collapse All":
					view.sectorGrid.collapseAll();
					break;
			}
		}
		private function initEventListeners():void
		{
			view.saveBtn.addEventListener(MouseEvent.CLICK, onSaveClick);
			//view.closeBtn.addEventListener(MouseEvent.CLICK, onCloseClick);
			//view.addEventListener(UserProfileEvent.NEW_VIEW_MODEL, onCreationComplete);
		}
		private function initBindings():void
		{
			// Bindings are not working - i don't know why - so i am just setting dataProviders manually
			//bind(view.lineOfBusinessComboBox, "dataProvider", this, ["model", "lineOfBusinessList"]);
			view.lineOfBusinessComboBox.dataProvider = model.lineOfBusinessList;
			//bindSetter(onSourceChange,this,["model","source"]);
		}
		private function enableCommands():void
        {
        	view.actions.getCommand(AllowableCommand.COMMAND_SAVE).EnableCommand(view,null,onSaveClick);
        }

        private function onSaveClick(e:MouseEvent = null,closeAfterSave:Boolean = false):void
        {
        	var slsp:SectorLeadServiceProxy = SectorLeadServiceProxy.getInstance();
        	var hasErrors:Boolean = false;
        	var message:String = "";
        	var hashMap:Dictionary = new Dictionary();
        	var dupeMessage:String = "";

        	for each ( var ssw:StateSectorWrapper in model.SSLIs )
        	{
        		for each ( var ssli:StateSectorLeadInfo in ssw.theSSLI )
        		{
        			if ( ssli.changesToSave )
        			{
        				for each ( var sla:SectorLeadAssignment in ssli.leadAssignments)
        				{
        					if (sla.team.code == null)
        					{
        						message += "Please select a team for state : " + ssli.state.name + "\n";
        					}
        					if (sla.leadAnalyst.fullName == "" || sla.leadAnalyst.fullName == null)
        					{
        						message += "Please select a lead analyst for state : " + ssli.state.name + "\n";
        					}
        				}
        				// first create a map with all the properties of each sector lead assignment
        				for each ( var sla:SectorLeadAssignment in ssli.leadAssignments)
        				{
        					var key:String = ssli.state.name + ":" ;
        					var count:Number = 0;

        					if (sla.team != null &&
        						sla.sectorGroup != null &&
        						sla.sector != null &&
        						sla.subsector != null)
        					{
        						key += sla.team.code + ":" + sla.sectorGroup.code + ":" + sla.sector.code + ":" + sla.subsector.code;
        					}
        					else if (sla.team != null &&
        						sla.sectorGroup != null &&
        						sla.sector != null )
        					{
        						key += sla.team.code + ":" + sla.sectorGroup.code + ":" + sla.sector.code;
        					}
        					else if (sla.team !=null)
        					{
        						key += sla.team.code;
        					}else {
        						continue;
        					}
        					count = hashMap[key];
        					if (isNaN(count))
        					{
        						count = new Number(1);
        					} else {
        						count ++;
        					}
        					hashMap[key] = count;
        				}
        				// now verify if any row is duplicated
        				for each ( var sla:SectorLeadAssignment in ssli.leadAssignments)
        				{
        					var key:String = ssli.state.name + ":" ;
        					var count:Number = 0;

        					if (sla.team != null &&
        						sla.sectorGroup != null &&
        						sla.sector != null &&
        						sla.subsector != null)
        					{
        						key += sla.team.code + ":" + sla.sectorGroup.code + ":" + sla.sector.code + ":" + sla.subsector.code;
        					}
        					else if (sla.team != null &&
        						sla.sectorGroup != null &&
        						sla.sector != null )
        					{
        						key += sla.team.code + ":" + sla.sectorGroup.code + ":" + sla.sector.code;
        					}
        					else if ( sla.team != null)
        					{
        						key += sla.team.code;
        					}
        					else {
        						continue;
        					}

        					count = hashMap[key];

        					if (isNaN(count))
        					{
        						// do nothing
        					} else {
        						if ( count > 1 ){
        							// error
        							var z:int = key.indexOf(":");
        							if ( dupeMessage == "There is a duplicate row for " + key.substring(0,z) + "\n")
        							{
        								// do nothing
        							}else{
        								dupeMessage = "There is a duplicate row for " + key.substring(0,z) + "\n";
        							}
        						}
        					}
        				}

        				if ( message == "" && dupeMessage == "")
        				{
        					ssli.group = model.theGroup;
        					slsp.updateStateSectorLeads(ssli , onSSLIUpdated, onSSLIUpdateFail);
        				}
        			}
        		}
        	}
        	if ( message != "" || dupeMessage != "" )
        	{
        		var validationMessage:Message = new Message();
				var validationErrors:Array = new Array();
				validationMessage.message = message + dupeMessage;

				validationErrors.push(validationMessage);

				var validationResult:ValidationResult = new ValidationResult();
				validationResult.errors = new ArrayCollection(validationErrors);
				validationResult.warnings = null;

				var validationPopup:ValidationPopup=ValidationPopup(PopUpManager.createPopUp(Application.application.document, ValidationPopup, true));
				validationPopup.validationResult=validationResult;
				validationPopup.sourceEvent = null;
				PopUpManager.centerPopUp(validationPopup);
        	}else{
        		if ( closeAfterSave )
        		{
        			returnToLastView();
        		}
        	}

        }
        private function onSSLIUpdated(ssli:StateSectorLeadInfo):void
        {
        	// trace(ssli.state.name + " updated successfully");
        	/*
        	var popup:ConfirmSystemChangePopup = ConfirmSystemChangePopup(PopUpManager.createPopUp(view.parentApplication.document, ConfirmSystemChangePopup, true));
			PopUpManager.centerPopUp(popup);
			popup.width = 400;
			popup.title = "Update successful";
			popup.Message.text = ssli.state.name + "updated successfully";
			popup.btnCancel.visible = false;
			popup.btnNo.visible = false;
			popup.btnSubmit.label = "OK";
			*/
			model.userHasMadeChanges = false;
        }
        private function onSSLIUpdateFail(err:Fault = null):void
        {
        	var validationMessage:Message = new Message();
			var validationErrors:Array = new Array();
			validationMessage.message = "Update Failed \n" ;
			if ( err )
			{
				validationMessage.message += err.faultString;
			}

			validationErrors.push(validationMessage);

			var validationResult:ValidationResult = new ValidationResult();
			validationResult.errors = new ArrayCollection(validationErrors);
			validationResult.warnings = null;

			var validationPopup:ValidationPopup=ValidationPopup(PopUpManager.createPopUp(Application.application.document, ValidationPopup, true));
			validationPopup.validationResult=validationResult;
			validationPopup.sourceEvent = null;
			PopUpManager.centerPopUp(validationPopup);
        }
        private function onCloseClick(e:Event = null):Boolean
        {
        	if ( model.userHasMadeChanges )
			{
				//  An old popup that we don't use anymore
//				var popup:ConfirmSystemChangePopup = ConfirmSystemChangePopup(PopUpManager.createPopUp(view.parentApplication.document, ConfirmSystemChangePopup, true));
//				PopUpManager.centerPopUp(popup);
//				popup.width = 400;
//				popup.title = "Save Before Closing";
//				popup.Message.text =
//					"Any unsaved changes will be lost.\n\n" +
//					"Save before closing ? " ;
//				popup.btnCancel.label = "Cancel"
//				popup.btnNo.visible = true;
//				popup.btnNo.label = "No";
//				popup.btnSubmit.label = "Save";
//				popup.addEventListener(PopupEvent.YES,
//					function (evt:PopupEvent):void
//					{
//						onSaveClick(null,true);
//					}
//				);
//				popup.addEventListener(PopupEvent.NO, returnToLastView);
//			} else {
//				returnToLastView();
//			}

				//==========================================================================
				//   This popup is the "Generic" application standard (supposedly)
				//===========================================================================

				var message:String = "Do you want to save changes to this Sector Lead?";
               	var confirmPopUp:ConfirmPopup
               		=AlertUtil.show(message, null, "Save", AlertUtil.YES|AlertUtil.NO|AlertUtil.CANCEL, this["view"], null,"Save and Close", "Discard Changes", cancelHandler,onSaveHandler,onCloseHandler );

          		confirmPopUp.width=500;
          		confirmPopUp.btnCancel.width=120;
          		confirmPopUp.btnYes.width=120;
          		confirmPopUp.btnNo.width=120;
          		confirmPopUp.btnCancel.setFocus();

          		return false;
   			}else{
   				return true;
   			}
        }

        private function cancelHandler(e:Event=null):void
        {
        	// closes itself - do nothing
        }
        private function onCloseHandler(event:Event):void
        {
	         returnToLastView();
        }
        private function onSaveHandler(event:Event):void
        {
	       	onSaveClick(null,true);// true here makes function close if successful save
        }

        private function initControls():void
        {
        	view.lineOfBusinessComboBox.selectedIndex = -1;
        	view.lineOfBusinessComboBox.prompt = "Public Finance Group";
        	view.lineOfBusinessComboBox.enabled = false;

        	// set groupMd name label
        	var lobl:ArrayCollection = new ArrayCollection();
	    	var grp:ReferenceObject = new ReferenceObject();
	    	lobl = view.references.lineOfBusinessList;
	    	for ( var j:uint = 0; j < lobl.length ; j++)
        	{
        		if ( lobl[j].code == "PFG")
        		{
        			grp = lobl[j];
        			break;
        		}
        	}
        	// below freaky code is no longer the way to go...
        	// need to make service call instead

        	SecurityUserServiceProxy.getInstance().findGroupMDByGroupId(grp.id,onGetCurrentGroupMD,onGetCurrentGroupMDFaultHandler);
	   }

       	private function onGetCurrentGroupMD(teamMDs:ArrayCollection):void
		{
			var mds:String = "";

	    	if(teamMDs!=null)
	    	{
				for each (var MDName:String in ArrayCollection(teamMDs))
	    		{
	    			if(MDName.split(" ").length==2)
	    			{
	    				var MDNameAarray:Array=MDName.split(" ");
	    				var newMDNameAarray:Array=new Array();
	    				newMDNameAarray[1]=MDNameAarray[0];
	    				newMDNameAarray[0]=MDNameAarray[1];
	    				MDName=newMDNameAarray.join(", ");
    				}

    				if(mds=="")
    				{
    					mds = MDName ;
    				}
    				else
    				{
    					mds = mds + "; " + MDName ;
    				}
	    		}
	    	}

	    	view.groupMDLbl.text = MDName;

//	    	var mdAC:ArrayCollection = view.references.groupMDMap[grp.code];
//        	var md:String = (mdAC[0].name).toString();
//        	md = StringUtil.trim(md);
//        	var MDName:String;
//        	var MDNameAarray:Array=md.split(" ");
//	    	var newMDNameAarray:Array=new Array();
//	    	newMDNameAarray[1]=MDNameAarray[0];
//	    	newMDNameAarray[0]=MDNameAarray[1];
//	    	MDName=newMDNameAarray.join(", ");
//
//        	view.groupMDLbl.text = MDName;


		}

       	private function onGetCurrentGroupMDFaultHandler(fault:Object):void
		{

			Alert.show(fault.toString());
		}
	}
}