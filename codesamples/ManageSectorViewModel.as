package com.m.pyramid.profile.viewmodels
{
	import com.m.pyramid.controls.MVCModel;
	import com.m.pyramid.controls.MVCView;
	import com.m.pyramid.model.ReferenceObject;
	import com.m.pyramid.model.StateSectorLeadInfo;
	import com.m.pyramid.model.helpers.Message;
	import com.m.pyramid.model.helpers.ValidationResult;
	import com.m.pyramid.profile.StateSectorWrapper;
	import com.m.pyramid.profile.views.ManageSectorView;
	import com.m.pyramid.services.SectorLeadServiceProxy;
	import com.m.pyramid.validation.ValidationPopup;

	import flash.events.Event;
	import flash.events.IEventDispatcher;

	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.collections.SortField;
	import mx.core.Application;
	import mx.managers.PopUpManager;
	import mx.rpc.Fault;

	public class ManageSectorViewModel extends MVCModel
	{
		[Bindable]
		public var lineOfBusinessList: ArrayCollection;

		[Bindable]
		public var SSLIs:ArrayCollection;

		[Bindable]
		public var usStates:ArrayCollection;

		[Bindable]
		public var expandedOrContracted:String = EXPAND_STATE;

		[Bindable]
		public var sslisPopulated:Boolean = false;

		[Bindable]
		public var newVar:int = -1;

		[Bindable]
		public var userHasMadeChanges:Boolean = false;

		public var slsp:SectorLeadServiceProxy;
		public var theGroup:ReferenceObject;
		public var currentlySelectedTeam:ReferenceObject;
		public var numberOfServiceCallsToMake:uint = 0;
		public var numberOfServiceCallsReturned:uint = 0;

		public var getStateSectorLeadsFailed:Boolean = false;
		public var getStateSectorLeadsFaultString:String = "";

		public const EXPAND_STATE:String = "Expand";
	    public const COLLAPSE_STATE:String = "Collapse";


		//Overview of the model data structure
		//
		//  SSLIs   :  an ArrayCollection of StateSectorWrappers
		//
		//		StateSectorWrapper    :    A class that has two properties
		//			state : ReferenceObject
		//			theSSLI : ArrayCollection          of StateSectorLeadInfos
		//
		//			StateSectorLeadInfo
		//				state : ReferenceObject
		//				leadAssignments : ArrayCollection        of  SectorLeadAssignments
		//
		//				SectorLeadAssignments
		//					team : ReferenceObject
		//					sectorGroups : ReferenceObject
		//					sector : ReferenceObject
		//					subsector : ReferenceObject
		//					leadAnalyst : User
		//					backupAnalyst : User

		public function ManageSectorViewModel(target:IEventDispatcher=null)
		{
			title = "Manage Sector Leads";
			editable = true;
			viewClass = ManageSectorView;
			showClose = true;
		}
		public function populateNewModelFromView(view:MVCView):void
		{
			slsp = SectorLeadServiceProxy.getInstance();
			usStates = new ArrayCollection();
			lineOfBusinessList = view.references.lineOfBusinessList;
			getStateSectorLeadsFailed = false;
			getStateSectorLeadsFaultString = "";

			slsp.getAllStates(onGotStates ,onFail);

			// once states are populated we will populate sslis
		}
		private function onGotStates(sts:ArrayCollection):void
		{
			usStates = sts;

			sortStates();

			//if ( ! sslisPopulated )
			//{
			SSLIs = new ArrayCollection();
			populateSSLIs();
			//}
		}
		private function sortStates():void
		{
			var sortField:SortField = new SortField("label", true, false);
        	var sort:Sort = new Sort();
        	sort.fields = [sortField];
        	usStates.sort = sort;
        	usStates.refresh();
		}
		private function populateSSLIs():void
        {
        	var grp:ReferenceObject = new ReferenceObject();

        	for ( var j:uint = 0; j < lineOfBusinessList.length ; j++)
        	{
        		if ( lineOfBusinessList[j].code == "PFG")
        		{
        			grp = lineOfBusinessList[j];
        			theGroup = grp;
        		}
        	}
        	numberOfServiceCallsToMake = usStates.length;
        	numberOfServiceCallsReturned = 0;
        	for ( var i:uint = 0 ; i < usStates.length; i++)
        	{
				slsp.getStateSectorLeads(grp,usStates[i], onReturnedSSLI, onFail);
        	}
        	if ( getStateSectorLeadsFailed ) displayGetStateSectorLeadsFailMessage();
        }
        private function onReturnedSSLI( info:StateSectorLeadInfo ):void
        {
        	sslisPopulated = true;
        	numberOfServiceCallsReturned++;
        	if (numberOfServiceCallsReturned == numberOfServiceCallsToMake)
        	{
	        	this.dispatchEvent(new Event(Event.COMPLETE));
        	}
        	var newSSLI:StateSectorLeadInfo = new StateSectorLeadInfo();
        	newSSLI = info;
        	var ssliWrapper : StateSectorWrapper = new StateSectorWrapper();
        	ssliWrapper.theSSLI.addItem(newSSLI);
        	ssliWrapper.state = newSSLI.state;
        	SSLIs.addItem(ssliWrapper);
        }
        private function onFail(f:Fault):void
        {
        	getStateSectorLeadsFaultString = f.faultString;
        	getStateSectorLeadsFailed = true;
        }
        private function displayGetStateSectorLeadsFailMessage():void
        {
        	var msg:String = "Error : " + getStateSectorLeadsFaultString;

        	var validationMessage:Message = new Message();
			var validationErrors:Array = new Array();
			validationMessage.message = msg;
			validationErrors.push(validationMessage);

			var validationResult:ValidationResult = new ValidationResult();
			validationResult.errors = new ArrayCollection(validationErrors);
			validationResult.warnings = null;

			var validationPopup:ValidationPopup=ValidationPopup(PopUpManager.createPopUp(Application.application.document, ValidationPopup, true));
			validationPopup.validationResult=validationResult;
			validationPopup.sourceEvent = null;
			PopUpManager.centerPopUp(validationPopup);
        }
	}
	/*
	// mock data created under here for testing purposes
				//==========================================================
				var newSSLI:StateSectorLeadInfo = new StateSectorLeadInfo();
				newSSLI.state = usStates[i];

				var sla:SectorLeadAssignment = new SectorLeadAssignment();
				var teamRefOb:ReferenceObject = new ReferenceObject();
				teamRefOb.code = "team aaa";
				sla.team = teamRefOb;
				var saiTex:User = new User();
				saiTex.firstName = "Sai";
				saiTex.lastName = "Tex";
				sla.backupAnalyst = saiTex;
					if(i==1)
					{
						var sla2:SectorLeadAssignment = new SectorLeadAssignment();
						var mary:User = new User();
						mary.firstName = "mary";
						var joe:User = new User();
						joe.firstName = "joe";
						sla2.leadAnalyst = mary;
						sla2.backupAnalyst = joe;
						newSSLI.leadAssignments.addItem(sla2);
						newSSLI.leadAssignments.addItem(sla2);
					}
				newSSLI.leadAssignments.addItem(sla);
				onReturnedSSLI(newSSLI);
				//==========================================================
				*/
}