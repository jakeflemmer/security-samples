package com.m.pyramid.managers
{
	import com.m.pyramid.alerts.JMSManager;
	import com.m.pyramid.application.PyramidLayoutManager;
	import com.m.pyramid.application.controllers.ApplicationController;
	import com.m.pyramid.components.AllowableCommands;
	import com.m.pyramid.components.IAllowableCommand;
	import com.m.pyramid.components.Security.LockableProperty;
	import com.m.pyramid.components.Security.PropertyLock;
	import com.m.pyramid.controls.MVCModel;
	import com.m.pyramid.controls.MVCView;
	import com.m.pyramid.controls.UILock;
	import com.m.pyramid.events.*;
	import com.m.pyramid.model.AllowableCommand;
	import com.m.pyramid.model.FlexObject;
	import com.m.pyramid.model.ReferenceObject;
	import com.m.pyramid.model.User;
	import com.m.pyramid.model.WorkItem;
	import com.m.pyramid.model.WorkItemPermission;
	import com.m.pyramid.services.Services;
	import com.m.pyramid.views.Case.*;

	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;

	import mx.collections.ArrayCollection;
	import mx.containers.FormItem;
	import mx.controls.*;
	import mx.core.Application;
	import mx.core.Container;
	import mx.core.UIComponent;
	import mx.messaging.ChannelSet;
	import mx.messaging.config.ServerConfig;
	import mx.messaging.events.MessageEvent;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.HTTPService;
	import mx.utils.StringUtil;

	[Bindable]
	public class SecurityManager
	{
		public var user:User;
		public static var allViewsAllButtonsMap:Object;
		public static var stateButtonsAllowedMap:Object;
		public static var menuItemsSecurityAC:ArrayCollection = new ArrayCollection();
		public static var blackFlexObjectAC:ArrayCollection = new ArrayCollection();// security debug data
		public static var whiteListAC:ArrayCollection = new ArrayCollection();// security debug data
		public static var screenBlackAC:ArrayCollection = new ArrayCollection();// security debug data
		public static var screenAllowedWhiteButtonsAC:ArrayCollection = new ArrayCollection();// security debug data
		public static var screenAllWhiteButtonsAC:ArrayCollection = new ArrayCollection();// security debug data
		public static var blackLocksMap:Dictionary = new Dictionary();
		public static var securityErrorLogs:Array = new Array();

		public function SecurityManager()
		{

		}

		public function login(userName:String, password:String):AsyncToken
		{
			user = new User();
			user.userName = userName;
			var channelSet:ChannelSet = getChannelSet();
			trace("Logging into channelSet[" + channelSet + "]");
			return channelSet.login(userName, password);
        }

		public function logout():AsyncToken
		{
			trace("SecurityManager.logout()...");
			var channelSet:ChannelSet = getChannelSet();
			return channelSet.logout();
        }

		private function getChannelSet():ChannelSet
		{
			var channelSet:ChannelSet = ServerConfig.getChannelSet("loginService");
			var app:MainApplication = Application.application.document as MainApplication;
			if (app.services is com.m.pyramid.services.Services)
			{
				if ((app.services as com.m.pyramid.services.Services).loginService.channelSet != null)
				{
					channelSet = (app.services as com.m.pyramid.services.Services).loginService.channelSet;
				}
			}
			return channelSet;
        }

		public function authorize(view:Object):void
		{
			SecurityManager.authorize(view);
		}

//=====================================================================================================
//  SECURITY
//=====================================================================================================
		// in the event that any employee is terminated they must immediately be logged out of Pyramid and
		// must lose their session and all data associated with it
		public static function subscribeForceLogout():void
		{
			var messageSelector:String = "eventType = 'logout' and userName = '" + StringUtil.trim(logonUser.userName) + "'";
			securityErrorLogs.push("messageSelector is : " + messageSelector);
			JMSManager.getInstance().createNewConsumer(	messageSelector,
													    forceLogoutHandler, forceLogoutFault );
		}
		public static function forceLogoutHandler(me:MessageEvent):void
		{
			var apEv:ApplicationEvent = new ApplicationEvent(ApplicationEvent.LOGOUT);
			apEv.isForcedLogout = true;
			Application.application.dispatchEvent(apEv);
		}
		public static function forceLogoutFault(e:Event = null):void
		{
			PFGError.throw$("forceLogoutFault : " + e);
		}

//=====================================================================================================
//  MAKE FINE GRAIN MAPS
//=====================================================================================================

		public static function makeFineGrainSecurityMaps(permissions:ArrayCollection):void
		{
			if ( ! ApplicationController.securityEnabled) return;

			if ( ! permissions ) return;

			whiteListAC = permissions;	// security debug data
			allViewsAllButtonsMap = new Object();
			stateButtonsAllowedMap = new Object();

			for(var i:int; i < permissions.length; i++)
			{
				if ( permissions[i] == null )
				{
					traceDebugStatement("SECURITY :: there is a null premission at row " + i.toString());
					continue;
				}

				var wip:WorkItemPermission = permissions[i] as WorkItemPermission;
				var view:String = wip.flexObject.qualifiedClassName;
				var chain:Array = wip.flexObject.chain;

								if ( wip.workItemStatus == null )
								{
									traceDebugStatement("SECURITY :: there is no workItemStatus at row " + i.toString());
									continue;
								}

				var status:String = wip.workItemStatus.code;
				var entityType:String = "";
				if(wip.entityType != null) entityType = wip.entityType.code;

				if ( allViewsAllButtonsMap[view] == null) allViewsAllButtonsMap[view] = new ArrayCollection();

				allViewsAllButtonsMap[view].addItem(wip);

				if (stateButtonsAllowedMap[view] == null) stateButtonsAllowedMap[view] = new Dictionary();

				if ( stateButtonsAllowedMap[view][entityType+status] == null)
					stateButtonsAllowedMap[view][entityType+status] = new ArrayCollection();

				stateButtonsAllowedMap[view][entityType+status].addItem( wip.flexObject );
			}
		}

		public static function readMapToGetWhiteListedButtons(view:String,model:MVCModel,workitem:WorkItem,state:ReferenceObject):ArrayCollection
		{

			if ( ! workitem ) return null;
			if ( ! workitem.entityType ) return null;
			if ( workitem.entityType.code == null || workitem.entityType.code == "") return null;

			var whiteList:ArrayCollection;
			var entityTypeRO:ReferenceObject = workitem.entityType;
			var status = state.code;
			var entityType:String = entityTypeRO.code;

			// right here is where the map is read !!
			whiteList = stateButtonsAllowedMap[view][entityType+status];
			return whiteList;
		}

//=====================================================================================================
//  COMPARE BLACK AND WHITE LISTS FOR OVERLAPS
//=====================================================================================================

public static function compareBlackAndWhiteListsForOverlap():void
{
	// this function is here to solve the problem of the same controls beings controlled by multiple PG's ( an overlap )
	// 		if a button is allowed in a certain work item state but not having that PG should not blacklist that button
	// 		because that button is also permissioned by another PG then there is an overlap
	// in this situation the UIC must be removed from the blackList and this function will do that

		var d:Dictionary = SecurityManager.logonUser.permissions as Dictionary;
		var qcn:String;				// qualified class name
		var uic:String;				// ui component
		var witWis:String;		// work item type and work item status which is the key to the map

		for ( qcn in d )
		{
			if ( stateButtonsAllowedMap[qcn] )
			{
				var wd:Dictionary = stateButtonsAllowedMap[qcn] as Dictionary;	// white list dictionary

				for ( witWis in wd )
				{
					var ac:ArrayCollection = wd[witWis] as ArrayCollection;

					for ( var i :uint =0 ; i < ac.length; i++)
					{
						var flexObject:FlexObject = ac[i] as FlexObject;
						var wca:Array = flexObject.chain;  // white chain array
						var wcid:String = wca[0]; // white control ID
						for ( var j:uint=1; j < wca.length-1; j++)
						{
							wcid += "."+wca[j];
						}
						// now we have in our hand the control ID on the flex object on the white list
						// if there is also the same flexobject control ID for this view on the black list
						//		then this flexobject must be removed from the black list

						var thisViewsArrayOfFlexObjects:Array = d[qcn] as Array;

						d[qcn] = thisViewsArrayOfFlexObjects.filter(
							function (element:*, index:int, arr:Array):Boolean {
								var bca:Array = (element as FlexObject).chain;  // black chain array
								var bcid:String = bca[0];
								for ( var k:uint=1 ; k < bca.length -1; k++)
								{
									bcid += "."+bca[k];
								}
								var retVal:Boolean = ( bcid != wcid )
								return retVal;
        					}
        				);
       				}
				}
			}
		}
}


//=====================================================================================================
//  MENU ITEMS SECURITY
//=====================================================================================================
		public static function doMenuItemSecurity():void
		{
			for ( var i:uint =0; i < menuItemsSecurityAC.length; i++)
			{
				var flexObject:FlexObject = menuItemsSecurityAC[i];
				var code:String = flexObject.chain[0];
				var Iac:IAllowableCommand = PyramidLayoutManager.getInstance().getItem(code);
				if (Iac != null)
				{
					var ac:AllowableCommand = Iac as AllowableCommand;
					placeLockOnCommand(ac);
				}
			}
		}


//=====================================================================================================
//  COARSE GRAIN   or    BLACK LIST
//=====================================================================================================
		public static function doCoarseGrainSecurity(view:Object):void
		{
			var blackList:Array = getBlackList(view);
			if ( blackList != null )
				screenBlackAC.source = blackList;	// security debug data
			else
				 return;

			var isCommand:Boolean;

			for each(var blackFlexObject:FlexObject in blackList)
			{
				isCommand = false;

				for ( var i :uint =0; i < blackFlexObject.chain.length; i++)
				{
					if ( blackFlexObject.chain[i] == "actions" )
					{
						isCommand = true;
						var ac:AllowableCommand = getAllowableCommandOnFlexObject(view,blackFlexObject);
						if ( ac )
						{
							placeLockOnCommand(ac);
							continue;
						}
					}
				}
				if ( ! isCommand )
				{
					var uic:UIComponent = getUIComponentOnFlexObject(view,blackFlexObject);
					if ( ! uic )
					{
						if ( blackFlexObject)
						{
						 traceDebugStatement("NO SUCH UIC : " + blackFlexObject.propertyChain);
						} else {
						 traceDebugStatement("NO SUCH UIC !!");
						}
						continue;
					}
					if (blackLocksMap[view] == null) blackLocksMap[view] = new Object();
					if ( blackLocksMap[view][blackFlexObject.propertyChain] == null )
					{
						if ( ! uic.initialized)
						{
								uic.callLater(calledLaterMaxLockOnUIC,[blackFlexObject,uic,view]);
						}else {
							var lp:LockableProperty = makeLockableProperty(blackFlexObject)
							blackLocksMap[view][blackFlexObject.propertyChain] = placeMaxLockOnUIC(uic,lp);
						}
					} else {
						if ( (blackLocksMap[view][blackFlexObject.propertyChain] as PropertyLock).isLocked != true )
						{
							(blackLocksMap[view][blackFlexObject.propertyChain] as PropertyLock).isLocked = true;
						}
					}
				}
			}
		}
		public static function calledLaterMaxLockOnUIC(blackFlexObject:FlexObject,uic:UIComponent,view:Object):void
		{
			if ( blackLocksMap[view][blackFlexObject.propertyChain] == null )
			{
				var lp:LockableProperty = makeLockableProperty(blackFlexObject)
				blackLocksMap[view][blackFlexObject.propertyChain] = placeMaxLockOnUIC(uic,lp);
			}
		}

//=====================================================================================================
//  FINE GRAIN SECURITY     OR    WHITE LIST
//=====================================================================================================

		public static function doFineGrainSecurity(view:MVCView,model:MVCModel,workitem:WorkItem,state:ReferenceObject):void
		{

			if ( ! ApplicationController.securityEnabled) return;

			if ( state.code == null ) state.code = "NOT_STARTED";

			var viewString:String = getQualifiedClassName(view)

			if (lockAllStateButtonsForView(view,viewString)) // return true if there is a white list for this view
			{
				var whiteList:ArrayCollection =	readMapToGetWhiteListedButtons(viewString,model,workitem,state);

				traceDebugInfo(whiteList,viewString,workitem,state);

				unlockWhiteListedStateButtons(view, whiteList);
			}
		}

//========================================================================================================
//=============================       SECURITY UTILITY METHODS     ========================================
//========================================================================================================

		public static function getBlackList(view:Object):Array
		{
			var host:String = getQualifiedClassName(view);
			if(SecurityManager.logonUser != null)
			{
					var m:Object = SecurityManager.logonUser.permissions;
			}
			if(SecurityManager.logonUser != null && SecurityManager.logonUser.permissions[host] != null)
			{
				var blackList:Array = SecurityManager.logonUser.permissions[host] as Array;
				return blackList;
   			}
   			return null;
		}
		public static function getAllowableCommandOnFlexObject(view:Object, fo:FlexObject):AllowableCommand
		{
			var chain:Array = fo.chain;
			for (var i:uint=0; i < chain.length;i++)
			{
				if ( chain[i] == "actions" )
				{
					if (view.actions == null)
					{
						return null; // this means that security is being called on MVCViewInit but not yet on ContentInit
									 // actions will be null until Content is init and this method will be called again then
					}
					var d:Dictionary = view.actions.Codes;
					if ( d[chain[i+1]] is AllowableCommand )
					{
						var ac:AllowableCommand = d[chain[i+1]] as AllowableCommand;
						return ac;
					}else return null;

				}
			}
			return null;
		}
		public static function getUIComponentOnFlexObject(view:Object,fo:FlexObject):UIComponent
		{
			var chain:Array = fo.chain;
			var uic:UIComponent = view as UIComponent;
			for ( var i:uint=0 ; i < chain.length -1 ;i++)
			{
				if ( uic.hasOwnProperty(chain[i]))
				{
					if ( uic[chain[i]] is UIComponent )
					{
						uic = uic[chain[i]] as UIComponent;
					}
					else
					{
						traceDebugStatement("SECURITY : this is not a UIComponenet : "+ view.toString() +"["+chain[i].toString()+"]");
						return null;
					}
				} else {
					traceDebugStatement("SECURITY: no such property as " + chain[i].toString() + " on " + view.toString());
					return null;
				}
			}
			return uic;
		}

		public static function makeLockableProperty(fo:FlexObject):LockableProperty
		{
			var chain:Array = fo.chain;
			var len:int = fo.chain.length;
			var propertyToLock:String = chain[len-1];
			var lp:LockableProperty;
			var valueWhenLocked:Object = fo.value;
			var valueWhenUnlocked:Object = new Object();
			switch (valueWhenLocked)
			{
				case true:
					valueWhenUnlocked = false;
					break;
				case false:
					valueWhenUnlocked = true;
					break;
				default:
					valueWhenUnlocked = true;
					break
			}
			var jlp:LockableProperty;
			var events:String = eventType(propertyToLock);
			jlp = new LockableProperty(propertyToLock,valueWhenLocked,events);
			return jlp;
		}

		public static function placeLockOnCommand(ac:AllowableCommand):PropertyLock
		{
			var lp1:LockableProperty = new LockableProperty("allow",false,"enabledChanged",true);
			var lp2:LockableProperty = new LockableProperty("enable",false, "enabledChanged",true);
			var lock:PropertyLock = new PropertyLock(ac,[lp1,lp2],true,int.MAX_VALUE);
			traceDebugStatement("NEW lock created on AC : " + ac.label);
			return lock;

		}
		public static function placeLockOnModelEditableProperty( mod:MVCModel ):PropertyLock
		{
			var lp1:LockableProperty = new LockableProperty("editable",false,"enabledChanged",true);
			lp1.underlyingValue = true;
			var lock:PropertyLock = new PropertyLock(mod,[lp1],true,int.MAX_VALUE);
			traceDebugStatement("NEW lock created on model editable ");
			return lock;
		}

		public static function makeFlexObjects(string:String):FlexObject
		{
			var fo:FlexObject = new FlexObject();
			fo.propertyChain = string;
    		return fo;
		}
		public static function lockAllStateButtonsForView(view:MVCView,viewString:String):Boolean
		{
			var allViewsAllButtonsWIPList:ArrayCollection = allViewsAllButtonsMap[viewString];
			if ( allViewsAllButtonsWIPList )
				screenAllWhiteButtonsAC = allViewsAllButtonsWIPList;	// security debug data

			if ( ! allViewsAllButtonsWIPList )
			{
				traceDebugStatement("allViewsAllButtonsWIPList was null for "+viewString);
				return false;
			}
			// make a map to check that there are no duplicate flex objects
			var flexObjectStringsList:ArrayCollection = new ArrayCollection();
			var i :uint;

			for (i =0; i < allViewsAllButtonsWIPList.length; i++)
			{
				flexObjectStringsList.addItem( (allViewsAllButtonsWIPList[i] as WorkItemPermission).flexObject.propertyChain ); // property chain is one long string
			}

			var flexObjectsMap:Object = new Object();
			var nonDuplicatedFlexObjectList:ArrayCollection = new ArrayCollection();

			for ( i = 0; i < flexObjectStringsList.length; i++)
			{
				if ( flexObjectsMap[flexObjectStringsList[i]] == null )
				{
					flexObjectsMap[flexObjectStringsList[i]] = new Number(1);
					nonDuplicatedFlexObjectList.addItem(flexObjectStringsList[i]);
				} else {
					flexObjectsMap[flexObjectStringsList[i]] += 1;
				}
			}

			var blackList:ArrayCollection = new ArrayCollection();
			for ( i =0 ; i < nonDuplicatedFlexObjectList.length ; i++)
			{
				blackList.addItem( makeFlexObjects(nonDuplicatedFlexObjectList[i]) );
			}
			// now we have a black list of flex objects to lock ( all buttons all commands (state dependent) of this view
			for each(var blackFlexObject:FlexObject in blackList)
			{
				var ac:Object =	getAllowableCommandOnFlexObject(view,blackFlexObject);
				if ( ac != null )
				{
					if ( ac is AllowableCommand)
					{
						if (view.locksMap[blackFlexObject.propertyChain] == null)
						{
							var pl:PropertyLock = placeLockOnCommand(ac as AllowableCommand);
							view.locksMap[blackFlexObject.propertyChain] = pl;
						} else {
							(view.locksMap[blackFlexObject.propertyChain] as PropertyLock).isLocked = true;
						}
						traceDebugStatement("fine grain lock placed on AC : "+ ac.label);
					}
				} else {

					var uic:UIComponent = getUIComponentOnFlexObject(view,blackFlexObject);
					if ( ! uic )
					{
						traceDebugStatement("NO SUCH UI componenet - view : " + view.toString() + " - bfo.chain[0] : " + blackFlexObject.chain[0].toString());
						continue;
					}
					if (view.locksMap[blackFlexObject.propertyChain] == null)
					{
						var lp:LockableProperty =	makeLockableProperty(blackFlexObject)
						var pl: PropertyLock = placeMediumLockOnUIC(uic,lp);
						view.locksMap[blackFlexObject.propertyChain] = pl;

					} else {
						if ( ((view.locksMap[blackFlexObject.propertyChain] as PropertyLock).isLocked) != true  )
						{
								(view.locksMap[blackFlexObject.propertyChain] as PropertyLock).isLocked = true;

								if ( uic is Button)
								{
									traceDebugStatement("fine grain lock relocked on ButtonID: " + (uic as Button).id);

								}else{
									traceDebugStatement("fine grain lock relocked on UIC : " + uic.toString());
								}
						}
					}
				}
			}
			return true;
		}

		public static function unlockWhiteListedStateButtons(view:MVCView, whiteList:ArrayCollection):void
		{
			for each (var whiteFlexObject:FlexObject in whiteList)
			{
				if ( view.locksMap[whiteFlexObject.propertyChain] == null )
				{
					// there is no lock in the first place
					err = "went to unlock but no lock found for : " + (view.locksMap[whiteFlexObject]).toString();
					securityErrorLogs.push(err);
				} else {

					(view.locksMap[whiteFlexObject.propertyChain] as PropertyLock).isLocked = false;

					if ( ((view.locksMap[whiteFlexObject.propertyChain] as PropertyLock)._target) is Button)
					{
						traceDebugStatement("unlocked Button : " + (((view.locksMap[whiteFlexObject.propertyChain] as PropertyLock)._target) as Button).label);
					}else if( ((view.locksMap[whiteFlexObject.propertyChain] as PropertyLock)._target) is AllowableCommand)
					{
						traceDebugStatement("unlocked AC : " + (((view.locksMap[whiteFlexObject.propertyChain] as PropertyLock)._target)as AllowableCommand).label);
					}else{
						traceDebugStatement("unlocked : " + ((view.locksMap[whiteFlexObject.propertyChain] as PropertyLock)._target).toString());
					}
				}
			}
		}

		public static function eventType(propertyToLock:String):String
		{
			var events:String = "";
			switch(propertyToLock)
			{
				case "enabled":
					events = "enabledChanged";
					break;
				case "editable":
					events = "editableChanged";
					break;
				case "visible":
					events = "hide,show";
					break;
				case "includeInLayout":
					events = "includeInLayoutChanged";
					break;
				case "securityScreenEditable":
					events = "bogusEvent";   // this property should not be set by any business logic code so there is no event to listen for
					break;
				case "security_ScreenEditable":
					events = "bogusEvent";   // this property should not be set by any business logic code so there is no event to listen for
					break;
				case "security_screenEditable":
					events = "bogusEvent";   // this property should not be set by any business logic code so there is no event to listen for
					break;
				case "securityCloseBypass":
					events = "bogusEvent";   // this property should not be set by any business logic code so there is no event to listen for
					break;
			}
			return events;
		}

		public static function placeMediumLockOnUIC(thingLocked:EventDispatcher, lockableProperty:LockableProperty):PropertyLock
		{
			var blackLock:PropertyLock;
			var MEDIUM_STRENGTH:int = int.MIN_VALUE;
			blackLock = new PropertyLock(thingLocked,[lockableProperty],true,MEDIUM_STRENGTH);

			if ( thingLocked is Button)
			{
				traceDebugStatement("fine grain lock created and placed on ButtonID: " + (thingLocked as Button).id);
			}else{
				traceDebugStatement("fine grain lock created and placed on UIC : " + thingLocked.toString());
			}
			return blackLock;
		}

		public static function placeMaxLockOnUIC(thingLocked:EventDispatcher, lockableProperty:LockableProperty):PropertyLock
		{
			var blackLock:PropertyLock;
			var MAX_STRENGTH:int = int.MAX_VALUE;
			if ( thingLocked is Button)
			{
				traceDebugStatement("NEW lock created on Button : " + (thingLocked as Button).label);
			}else{
				traceDebugStatement("NEW lock created on UIC : " + thingLocked.toString());
			}
			blackLock = new PropertyLock(thingLocked,[lockableProperty],true,MAX_STRENGTH);
			return blackLock;
		}

//========================================================================================================
//   DEBUG INFORMATION
//========================================================================================================

	// a convenience screen was developed that allowed us to check each user's permissions
	// and see what on each screen was being locked by security
	// or if there was faulty security information send from the services

	public static function traceDebugInfo(whiteList:ArrayCollection,viewString:String,workitem:WorkItem,state:ReferenceObject):void
	{
		// for debug pupose only
		if ( whiteList )
		{
			screenAllowedWhiteButtonsAC = whiteList;
		}else{
			// do nothing
		}
		traceDebugStatement("NEW SCREEN : " + viewString + " : WorkItem : " + workitem.toString() + " : Status : " + state.code);
	}
	public static function traceDebugStatement(err:String):void{
		securityErrorLogs.push(err);
	}

//========================================================================================================
//   SESSION LOCK OUT
//========================================================================================================

		// when running in a secure evironment, the user must log in through IBM's TAM ( Tivoli Access Manager )
		// once logged in a cookie is stored in the user's browser which keeps them authenticated
		// co
		public static function doSessionLockOut():void
		{
			var srvc:HTTPService = new HTTPService();
			srvc.method = "POST";
			srvc.resultFormat = "text";
			//srvc.destination = "https://10.6.198.89/pkmslogin.form";
			//srvc.useProxy = true;

			var URL:String = "https://10.6.198.89/pkmslogin.form";

			var sendVars:Object = new Object();
			sendVars.username = "sec_tst_analyst@mis.mco.tld";
			sendVars.password = "T3st1ng!";
			sendVars["login-form-type"] = "pwd";
			sendVars.type = "HIDDEN";

			srvc.url = URL;

			srvc.addEventListener(ResultEvent.RESULT,onHTTPSrvcResult);
			srvc.addEventListener(FaultEvent.FAULT,onHTTPSrvcFault);

			srvc.send(sendVars);


		}
		public static function onHTTPSrvcResult(e:ResultEvent=null):void
		{
			Alert.show("http result : " + e.result);
		}
		public static function onHTTPSrvcFault(e:FaultEvent=null):void
		{
			Alert.show("THAT DIDN'T WORK : " + e.fault + "---" + e.message );
		}


//========================================================================================================
//========================================================================================================
// GENERATE MOCK DATA
//========================================================================================================
//========================================================================================================


//========================================================================================================
// GENERATE MOCK WHITE LIST
//========================================================================================================
public static function generateMockWhiteList():ArrayCollection
{
	var mockWhiteList:ArrayCollection = new ArrayCollection();
	var flexObject : FlexObject;
	var workItemPermission : WorkItemPermission ;

	flexObject  = makeFlexObject(1,"com.m.pyramid.enhancement.views::EnhancementView"
										,"saleDetails.ratingTeam.ratingTeamCombo");

	flexObject.propertyChain = "securityScreenEditable";

	workItemPermission = makeWIP(flexObject,"NOT_STARTED","NEW_CREDIT_ENH");

	mockWhiteList.addItem(workItemPermission);

	flexObject  = makeFlexObject(1,"com.m.pyramid.enhancement.views::EnhancementView"
										,"saleDetails.ratingTeam.ratingTeamCombo");

	flexObject.propertyChain = "editable";

		workItemPermission = makeWIP(flexObject,"NOT_STARTED","NEW_CREDIT_ENH");

	mockWhiteList.addItem(workItemPermission);

		flexObject  = makeFlexObject(1,"com.m.pyramid.enhancement.views::EnhancementView"
										,"saleDetails.ratingTeam.ratingTeamCombo");

	flexObject.propertyChain = "securityScreenEditable";

		workItemPermission = makeWIP(flexObject,"NOT_STARTED","NEW_CREDIT_ENH");

	mockWhiteList.addItem(workItemPermission);

	return mockWhiteList;
}
//========================================================================================================
// GENERATE MOCK WHITE LIST
//========================================================================================================
public static function generateMockBlackList():ArrayCollection
{
	var mockBlackList:ArrayCollection = new ArrayCollection();
	var flexObject : FlexObject;

	flexObject  = makeFlexObject(1,"com.m.pyramid.document.views::ManageLegalHoldView"
										,"saleDetails.ratingTeam.ratingTeamCombo");

	flexObject.propertyChain = "PG37";

	mockBlackList.addItem(flexObject);


	flexObject  = makeFlexObject(1,"com.m.pyramid.committeeAddendum.views::CommitteeAddendumView"
										,"saleDetails.ratingTeam.ratingTeamCombo");

	flexObject.propertyChain = "securityScreenEditable";
	mockBlackList.addItem(flexObject);

	flexObject  = makeFlexObject(1,"com.m.pyramid.committeeAddendum.views::CommitteeAddendumView"
										,"saleDetails.ratingTeam.ratingTeamCombo");

	flexObject.propertyChain = "securityFinalizedEditable";
	mockBlackList.addItem(flexObject);

	return mockBlackList;
}

public static function makeFlexObject(pg:uint,qcn:String,uic:String):FlexObject
{
	var pc:String = uic + ".enabled";
	var flexObject:FlexObject = new FlexObject();
	flexObject.permissionGroup ="PG1";
	flexObject.qualifiedClassName = qcn;
	flexObject.propertyChain = pc;

	return flexObject;
}
public static function makeWIP(flexObject:FlexObject,wis:String,et:String):WorkItemPermission
{
	var wip:WorkItemPermission = new WorkItemPermission();
	wip.flexObject = flexObject;

	var wisRO:ReferenceObject = new ReferenceObject();
	wisRO.code = wis;

	var etRO:ReferenceObject = new ReferenceObject();
	etRO.code = et;

	wip.workItemStatus = wisRO;
	wip.entityType = etRO;

	return wip;
}
// might want something like below function someplace at sometime
//		private function doLockingOrUnlocking(shouldBeLocked:Boolean,theLockableThing:UIComponent,propertyToLock:String):void{
//				var events:String = "enabledChanged";
//				if ( propertyToLock == "editable" ) events = "editableChanged";
//
//				if ( shouldBeLocked )
//				{
//					if ( editableLocksMap[theLockableThing] == null )
//						{
//							editableLocksMap[theLockableThing] = new PropertyLock( theLockableThing,[new LockableProperty(propertyToLock,false,events)],false,PropertyLock.LEVEL1_SECURITY);
//						}
//
//						if ( (editableLocksMap[theLockableThing] as PropertyLock).isLocked != true)
//								(editableLocksMap[theLockableThing] as PropertyLock).isLocked = true;
//				}
//				else
//				{
//					if ( (editableLocksMap[theLockableThing] as PropertyLock).isLocked == true)
//									(editableLocksMap[theLockableThing] as PropertyLock).isLocked = false;
//				}
//			}
//			public static function doLockingOrUnlocking(theLockableThing:UIComponent,propertyToLock:String,editableLocksMap:Object,shouldBeLocked:Boolean,lockLevel:int=0):void{
//				var events:String = SecurityManager.eventType(propertyToLock);
//
//				if ( shouldBeLocked )
//				{
//					if ( editableLocksMap[theLockableThing] == null )
//					{
//						editableLocksMap[theLockableThing] = new PropertyLock( theLockableThing,[new LockableProperty(propertyToLock,false,events)],false,
//													(( lockLevel != 0 ) ? lockLevel : PropertyLock.LEVEL1_SECURITY)  );
//					}
//						if ( (editableLocksMap[theLockableThing] as PropertyLock).isLocked != true)
//								(editableLocksMap[theLockableThing] as PropertyLock).isLocked = true;
//				}
//				else
//				{
//					if ( (editableLocksMap[theLockableThing] as PropertyLock).isLocked == true)
//									(editableLocksMap[theLockableThing] as PropertyLock).isLocked = false;
//				}
//			}

//========================================================================================================

	}
}