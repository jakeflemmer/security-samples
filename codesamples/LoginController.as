<?xml version="1.0" encoding="utf-8"?>
<MVCController
	xmlns="com.m.pyramid.controls.*"
	xmlns:mate="http://mate.asfusion.com/"
	xmlns:mx="http://www.adobe.com/2006/mxml">


	<mx:Script>
		<![CDATA[
			import com.m.pyramid.validation.ValidationPopup;
			import com.m.pyramid.model.helpers.ValidationResult;
			import com.m.pyramid.model.helpers.Message;
			import mx.core.Application;
			import mx.managers.PopUpManager;
			import com.m.pyramid.validation.ValidationPopup;
			import mx.collections.ArrayCollection;
			import com.m.pyramid.events.ApplicationEvent;
			import mx.controls.Alert;
			import mx.rpc.events.FaultEvent;
			import mx.rpc.events.ResultEvent;
			import mx.rpc.http.HTTPService;
			import com.m.pyramid.controls.MVCModel;
			import com.m.pyramid.application.views.AIRLoginView;
			import com.m.pyramid.application.viewmodels.AIRLoginModel;

			public var view:AIRLoginView;
			public var model:AIRLoginModel = new AIRLoginModel();

			public function start():void{
				initEventListeners();
				doPKMSLoginCredentials("tst_prd_mgr","Pyramid123!");
			}
			private function initEventListeners():void{
				view.loginButton.addEventListener(MouseEvent.CLICK, onLoginClick);
			}

			//=======================================================================
			//  EVENT HANDLERS
			//=======================================================================

			private function onLoginClick(me:MouseEvent):void{
				doPKMSLoginCredentials();
			}
			public function doPKMSLoginCredentials(u:String=null,p:String=null):void
			{
				var srvc:HTTPService = new HTTPService();
				srvc.method = "POST";
				srvc.resultFormat = "text";

				var username:String = view.usernameTextInput.text;
				var domain:String = (view.domainComboBox.selectedItem as String);
				var password:String = view.passwordTextInput.text;

				if ( p != null ) password = p;
				if ( u != null ) username = u;

				var URL:String = "https://" +  "pyramidpfgstg" + "/pkmslogin.form";
				var sendVars:Object = new Object();
				sendVars.username = "tst_analyst@ad.m.net";  //username + "@" + domain + ".m.net";			// "tst_analyst@ad.m.net";
				sendVars.password = "Pyramid123!"; //password; 				// "Pyramid123!";
				sendVars["login-form-type"] = "pwd";
				sendVars.type = "HIDDEN";

				srvc.url = URL;

				srvc.addEventListener(ResultEvent.RESULT, onResult);
				srvc.addEventListener(FaultEvent.FAULT, onLoginFault);

				srvc.send(sendVars);
			}
			public function onResult(e:ResultEvent):void
			{
				var rs:String = e.result.toString();
				if ( rs.search("Success") >= 0 )
				{
					view.visible = false;
					view.dispatchEvent(new ApplicationEvent(ApplicationEvent.LOGIN_COMPLETE));// listened for on application controller to initLogin
				}else {

					var m:String = "You have entered the wrong username and password. \n Please try again. If you need assistance contact the helpdesk at extension x4357.";

					var validationMessage:Message = new Message();
					var validationErrors:Array = new Array();
					validationMessage.message =  m;

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
			public function onCloseWrongPasswordAlert(e:Event=null):void
			{
				view.visible = true;
				view.loginButton.enabled = true;
			}
			public function onLoginFault(e:FaultEvent):void
			{
				view.visible = false;
				Alert.show("Invalid username or password");
			}

		]]>
	</mx:Script>

</MVCController>
