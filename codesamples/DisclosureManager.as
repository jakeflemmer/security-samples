package com.m.pyramid.disclosure
{
	import com.m.pyramid.application.NavigationEvent;
	import com.m.pyramid.components.alerts.AlertUtil;
	import com.m.pyramid.controls.MVCController;
	import com.m.pyramid.controls.MVCModel;
	import com.m.pyramid.disclosure.events.DisclosureEvent;
	import com.m.pyramid.disclosure.models.CreateDisclosureFormPopupModel;
	import com.m.pyramid.disclosure.models.DisclosureCorrectionModel;
	import com.m.pyramid.disclosure.models.DisclosureCorrectionSetupModel;
	import com.m.pyramid.error.PFGError;
	import com.m.pyramid.model.Case;
	import com.m.pyramid.model.Disclosure;
	import com.m.pyramid.model.DisclosureAttribute;
	import com.m.pyramid.model.DisclosureCorrection;
	import com.m.pyramid.model.DisclosureSetupInfo;
	import com.m.pyramid.model.Maturity;
	import com.m.pyramid.model.RatableEntity;
	import com.m.pyramid.model.Rating;
	import com.m.pyramid.model.RatingClass;
	import com.m.pyramid.model.RatingDetail;
	import com.m.pyramid.model.RatingShell;
	import com.m.pyramid.model.RatingWatch;
	import com.m.pyramid.model.Sale;
	import com.m.pyramid.services.CaseServiceProxy;
	import com.m.pyramid.services.RatingServiceProxy;

	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.external.ExternalInterface;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;

	import mx.collections.ArrayCollection;
	import mx.formatters.DateFormatter;
	import mx.utils.ObjectUtil;
	import mx.utils.StringUtil;

	public class DisclosureManager extends EventDispatcher
	{
		public static const MECHANICAL_WITHDRAW_AUTO_CREATE_MESSAGE:String = "The rating(s) you have chosen to withdraw are considered mechanical withdrawals.\n\nA Disclosure Form has been automatically created for these mechanical withdrawals and will replace any previously created Disclosure Form associated to this Rating Shell.";

		private static const RELEASED_TRANSACTION_DISCLOSURE_URL:String =
			"{0}/sff/previewDocument?documentId={1}&a_ids_identityType={2}&a_ids_identityNumber={3}&a_Rating={4}&a_RatingDate={5}&appId=PYRAMID&renderType=MDCP&contentType=PDF"

		public static var parentContext:Object;
		public static var frameworkURL:String;
		public static var doddFrankDate:Date;

		public static const FORM_TYPE_RATINGS:String = "Ratings";
		public static const FORM_TYPE_RATINGS_ON_WATCH:String = "RatingsAndOnWatch";
		public static const FORM_TYPE_ON_WATCH:String = "OnWatch";
		public static const FORM_TYPE_OFF_WATCH:String = "OffWatch";

		public function DisclosureManager()
		{

		}

		// OPEN THE FORM
		//===========================================================================
		// below function open a modal window from the rating shell and navigates to the disclosure form
		// when the modal window is closed it calls the callBackFunction
		public static function openDisclosureFormFromRatingShell(ratingShell:RatingShell, queryString:String, modalWindowClosedHandler:Function,newFormCreatedHandler:Function):void{

			if ( parentContext == null ) throw new Error("please give this a manager a parent context to dispatch events before calling this method");

			var disclosureID:Number;
			if ( ratingShell )
			{
				disclosureID = ratingShell.disclosureId;
			}
			if ( disclosureID == 0 || isNaN(disclosureID))
			{
				openCreateDisclosureFormPopup(ratingShell, newFormCreatedHandler);
			}
			else{
				openDisclosureForm(disclosureID,modalWindowClosedHandler, queryString);
			}
		}
		public static function openDisclosureFormFromDisclosureCorrection(dc:DisclosureCorrection, queryString:String, modalWindowClosedHandler:Function):void{

			if ( parentContext == null ) throw new Error("please give this a manager a parent context to dispatch events before calling this method");

			var disclosureID:Number;
			if ( dc && dc.disclosure )
			{
				disclosureID = dc.disclosure.disclosureDocumentId;
			}
			if ( disclosureID == 0 || isNaN(disclosureID))
			{
				throw new Error("service created a disclore correction work item that had a discloure with id = 0 or NaN !!");
			}
			else
			{
				openDisclosureForm(disclosureID, modalWindowClosedHandler, queryString);
			}
		}

		public static function openDisclosureForm(disclosureID:Number, modalWindowClosedHandler:Function=null, previewQueryString:String=null):void{
			// this function executes the javascript directly without requiring anything in the html wrapper :)
			if ( modalWindowClosedHandler) ExternalInterface.addCallback("asFunction",modalWindowClosedHandler);
				//TODO HARD CODING here needs to be addressed
				var URLString : String = frameworkURL + "/sff/editDocument.jsp?documentId="+disclosureID.toString()+"&toolbar=true&appId=PYRAMID";
				var appName:String = ExternalInterface.objectID;//"app";// TODO - HARD CODING - following appends a 0 to name for some reason? Application.application.name;

				if (previewQueryString)
				{
					var firstLetter:String = previewQueryString.charAt(0);
					if ( firstLetter != "&" )
					{
						URLString += "&" + previewQueryString;
					}else{
						URLString += previewQueryString;
					}
				}

				var script:XML =
				<script>
				    <![CDATA[
				           	function jsFunction(timer, url, appName) {
								timer = setTimeout(function() { window.showModalDialog(url,"","dialogWidth:900px;dialogHeight:700px");%appName%.asFunction();clearTimeout(timer); }, 1000);
				            }
				     	]]>
				</script>;

				var jsCode:String = String(script).replace(/%appName%/,appName);
				ExternalInterface.call(jsCode, null, URLString, appName);
		}
		public static function openReleasedDisclosureForm(disclosureId:Number):void{
			//service call wrapper to make sure the framework is not down
			RatingServiceProxy.getInstance().getDisclosureStatus(disclosureId,function(o:Object=null):void{
			var url:URLRequest = new URLRequest(frameworkURL + "/sff/previewDocument?documentId="+disclosureId.toString()+"&appId=PYRAMID&renderType=MDCP&contentType=PDF");
			navigateToURL(url,"_blank");	});
		}
		public static function openReleasedDisclosureFormDirectly(disclosureId:Number):void{
			// this function is called when we already know the common framework is not down
			var url:URLRequest = new URLRequest(frameworkURL + "/sff/previewDocument?documentId="+disclosureId.toString()+"&appId=PYRAMID&renderType=MDCP&contentType=PDF");
			navigateToURL(url,"_blank");
		}
		public static function openLinkedDisclosureForm(disclosureId:Number):void{
			//service call wrapper to make sure the framework is not down
			RatingServiceProxy.getInstance().getDisclosureStatus(disclosureId,function(o:Object=null):void{
			var url2:URLRequest = new URLRequest(frameworkURL + "/sff/previewDocument?documentId="+disclosureId.toString()+"&appId=PYRAMID&renderType=IF&contentType=PDF");
			navigateToURL(url2,"_blank");	});
		}
		public static function openLinkedDisclosureFormDirectly(disclosureId:Number):void{
			// this function is called when we already know the common framework is not down
			var url2:URLRequest = new URLRequest(frameworkURL + "/sff/previewDocument?documentId="+disclosureId.toString()+"&appId=PYRAMID&renderType=IF&contentType=PDF");
			navigateToURL(url2,"_blank");
		}
		public static function openMechanicalWithdrawalDisclosureFormAsViewOnly(disclosureId:Number):void{
			RatingServiceProxy.getInstance().getDisclosureStatus(disclosureId,function(o:Object=null):void{//service call wrapper to make sure the framework is not down
			var url:URLRequest = new URLRequest(frameworkURL + "/sff/previewDocument?documentId="+disclosureId.toString()+"&appId=PYRAMID&renderType=MDCP&contentType=PDF");
			navigateToURL(url,"_blank");	});
		}

		public static function openReleasedTransactionDisclosureForm(disclosureId:Number, ratableEntity:RatableEntity, rating:Rating):void
		{
			RatingServiceProxy.getInstance().getDisclosureStatus(disclosureId,function(o:Object=null):void{//service call wrapper to make sure the framework is not down

			var dateFormatter:DateFormatter = new DateFormatter();
			dateFormatter.formatString = "YYYY-MM-DD";

			var identityType:String = "";
			var identityNumber:String = "";
			var seniorityDescription = "";

			if(ratableEntity is Maturity)
			{
				identityType = "CUS";
				identityNumber = parseCUSIPNumber((ratableEntity as Maturity).cusipLabel);//pdtt00029206
				seniorityDescription = ratableEntity.description;
			}else if(ratableEntity is Sale){
				identityType = "MDY";
				identityNumber = ratableEntity.id.toString();
				seniorityDescription = ratableEntity.description;
			}else
			{
				identityType = "MDY";
				identityNumber = ratableEntity.id.toString();
				seniorityDescription = ratableEntity.name;
			}

			var ratingSymbol:String = rating.onWatchReason == null? rating.ratingSymbol.name : ""; //rating was clicked

			if(ratingSymbol.length > 0) //find corespondig watch
			{
				var listOfWatches:ArrayCollection = new ArrayCollection();
				var correspondingWatch:RatingWatch = null;

				if(rating.disclosure.disclosureType != null && rating.disclosure.disclosureType.code == Disclosure.EFFECTIVE_MECHANICAL_DISCLOSURE_TYPE &&
					rating.ratingClass != null && rating.ratingClass.shadow != null && rating.ratingClass.shadow.code == RatingClass.SHADOW_EFFECTIVE)
				{
					ratingSymbol = RatingDetail.RATING_CODE_WR;
				}

				for each(var ratingDetail:RatingDetail in ratableEntity.ratingDetails)
				{
					if(ratingDetail.newRating != null && ratingDetail.newRating.outstandingWatches != null)
					{
						listOfWatches.addAll(ratingDetail.newRating.outstandingWatches);
					}

					if(ratingDetail.outstandingRatingsHistory != null)
					{
						for each(var historicalRating:Rating in ratingDetail.outstandingRatingsHistory)
						{
							if(historicalRating.outstandingWatches != null)
							{
								listOfWatches.addAll(historicalRating.outstandingWatches);
							}
						}
					}

					correspondingWatch = DisclosureManager.findCorrespondingWatch(listOfWatches, ratingDetail.ratingClass, rating);

					if(correspondingWatch != null)
					{
						ratingSymbol += " - " + (correspondingWatch.direction !=null? correspondingWatch.direction.name : "");
						break;
					}

					listOfWatches.removeAll();
				}
			}
			else{

				if(rating.disclosure.disclosureType != null && rating.disclosure.disclosureType.code == Disclosure.EFFECTIVE_MECHANICAL_DISCLOSURE_TYPE &&
					rating.ratingClass != null && rating.ratingClass.shadow != null && rating.ratingClass.shadow.code == RatingClass.SHADOW_EFFECTIVE)
				{
					ratingSymbol = RatingDetail.RATING_CODE_WR;
				}else{

				ratingSymbol += (rating.ratingSymbol != null? rating.ratingSymbol.name : "") + " - " +
						(rating.onWatchReason != null? rating.onWatchReason.name : "");
				}
			}


			var url:String = StringUtil.substitute(RELEASED_TRANSACTION_DISCLOSURE_URL, frameworkURL, disclosureId.toString(), identityType,
				identityNumber, ratingSymbol, dateFormatter.format(rating.ratingDate));
			if (ratableEntity is Sale)
			{
				var sale:Sale = ratableEntity as Sale;
				if (sale.structuredFinanceDebt)
				{
					url += "&a_SF=" + (sale.structuredFinanceDebt.code == "Y" ? "true" : "false");
				}
				else
				{
					url += "&a_SF=false";
				}
			}
			navigateToURL(new URLRequest(url),"_blank");

			});
		}

		private static function parseCUSIPNumber(cusipNumber:String):String
		{
			var charactersToRemove:RegExp = /#/g;

			if(cusipNumber != null){
				return cusipNumber.replace(charactersToRemove, "%23");
			}else
			{
				return cusipNumber;
			}
		}

		public static function openReleasedMRSDisclosureForm(disclosureId:Number, ratableEntity:RatableEntity, rating:Rating, direction:String=null, date:Date=null, type:String=null):void
		{
			RatingServiceProxy.getInstance().getDisclosureStatus(disclosureId,function(o:Object=null):void{//service call wrapper to make sure the framework is not down

			var dateFormatter:DateFormatter = new DateFormatter();
			dateFormatter.formatString = "YYYY-MM-DD";

			var identityType:String = "";
			var identityNumber:String = "";
			var seniorityDescription = "";

			if(ratableEntity is Maturity)
			{
				identityType = "CUS";
				identityNumber = parseCUSIPNumber((ratableEntity as Maturity).cusipLabel);//pdtt00029206
				seniorityDescription = ratableEntity.description;
			}else if(ratableEntity is Sale){
				identityType = "MDY";
				identityNumber = ratableEntity.id.toString();
				seniorityDescription = ratableEntity.description;
			}else
			{
				identityType = "MDY";
				identityNumber = ratableEntity.id.toString();
				seniorityDescription = ratableEntity.name;
			}

			var ratingSymbol:String;
			if (type == DisclosureManager.FORM_TYPE_RATINGS)
			{
				ratingSymbol = rating.ratingSymbol.name;
			} else if ( type == DisclosureManager.FORM_TYPE_RATINGS_ON_WATCH)
			{
				ratingSymbol = rating.ratingSymbol.name;
				ratingSymbol += " - " + direction;
			} else if ( type == DisclosureManager.FORM_TYPE_ON_WATCH)
			{
				ratingSymbol = direction;
			} else if ( type == DisclosureManager.FORM_TYPE_OFF_WATCH)
			{
				ratingSymbol = direction;
			}


			var url:String = StringUtil.substitute(RELEASED_TRANSACTION_DISCLOSURE_URL, frameworkURL, disclosureId.toString(), identityType,
				identityNumber, ratingSymbol, dateFormatter.format(date));
			if (ratableEntity is Sale)
			{
				var sale:Sale = ratableEntity as Sale;
				if (sale.structuredFinanceDebt)
				{
					url += "&a_SF=" + (sale.structuredFinanceDebt.code == "Y" ? "true" : "false");
				}
				else
				{
					url += "&a_SF=false";
				}
			}
			navigateToURL(new URLRequest(url),"_blank");
			});
		}
		private static function findCorrespondingWatch(listOfWatches:ArrayCollection, watchRatingClass:RatingClass, rating:Rating):RatingWatch
		{
			var date1Copy:Date = null;
			var date2Copy:Date = null;

			for each(var ratingWatch:RatingWatch in listOfWatches)
			{
				if(ratingWatch.disclosure != null && ratingWatch.disclosure.disclosureDocumentId == rating.disclosure.disclosureDocumentId &&
					rating.ratingClass != null && rating.ratingClass.id == watchRatingClass.id)
				{
					date1Copy = ratingWatch.watchDate;
					date2Copy = rating.ratingDate;

					date1Copy.seconds = date2Copy.seconds = 0;
					date1Copy.milliseconds = date2Copy.milliseconds = 0;

					if(ObjectUtil.dateCompare(date1Copy, date2Copy) == 0)
					{
						return ratingWatch;
					}

				}
			}

			return null;
		}

		private static function findCorrespondingRating(listOfRatings:ArrayCollection, rating:Rating):Rating
		{
			var date1Copy:Date = null;
			var date2Copy:Date = null;

			for each(var ratingFromList:Rating in listOfRatings)
			{
				if(ratingFromList.disclosure != null && ratingFromList.disclosure.disclosureDocumentId == rating.disclosure.disclosureDocumentId &&
					rating.ratingClass != null && rating.ratingClass.id == ratingFromList.ratingClass.id)
				{
					date1Copy = ratingFromList.ratingDate;
					date2Copy = rating.ratingDate;

					date1Copy.seconds = date2Copy.seconds = 0;
					date1Copy.milliseconds = date2Copy.milliseconds = 0;

					if(ObjectUtil.dateCompare(date1Copy, date2Copy) == 0)
					{
						return ratingFromList;
					}

				}
			}

			return null;
		}

		// CREATE THE FORM
		//=========================================================================================
		// below flow is intended for when user clicks on the disclosureId link or the "regulatory disclosures" button on the rs
		// if there is no disclosure already associated with the rs then the create disclore popup is opened
		// unless its a mechanical withdrawal in which case a form is generated automatically
		// several functions are chained
		//======================================================================================
		public static function openCreateDisclosureFormPopup(ratingShell:RatingShell,newFormCreatedHandler:Function):void{

			//ordinarily we should open the createDisclosureFormPopup
			// However if this rating shell is a mechanical withdrawal then we should just create the form automatically
			// and display a message to the user explaining this
			RatingServiceProxy.getInstance().isMechanicalWithdrawal(ratingShell.id,
				function (boo:Boolean):void{
					if ( boo == true )
					{
						//just create the form automatically
						var dsi:DisclosureSetupInfo = new DisclosureSetupInfo();
						dsi.disclosureFormOption = DisclosureSetupInfo.CREATE_NEW;
						createDisclosureForm(ratingShell,dsi,newFormCreatedHandler);
						AlertUtil.show(MECHANICAL_WITHDRAW_AUTO_CREATE_MESSAGE, null, "Note");
					}else{
						continueToOpenCreateDisclosureFormPopup(ratingShell,newFormCreatedHandler);
					}
				});
		}
		public static function continueToOpenCreateDisclosureFormPopup(ratingShell:RatingShell,newFormCreatedHandler:Function):void{
			var cdfpm:CreateDisclosureFormPopupModel = new CreateDisclosureFormPopupModel();
			cdfpm.context = parentContext.model;
			cdfpm.displayCreateLaterOption = false;
			cdfpm.presearchSRSOnFindWorkItem = true;

			//cdfpm.context = this.model;	TODO - do we need the context?
			cdfpm.addEventListener(DisclosureEvent.CANCEL, function (e:Event):void{
				var ce:NavigationEvent = new NavigationEvent(NavigationEvent.CLOSEVIEW,e.currentTarget as CreateDisclosureFormPopupModel);
				(parentContext as MVCController).dispatcher.dispatchEvent(ce);
			});
        	cdfpm.addEventListener(DisclosureEvent.CONTINUE,
        	// below function is after the create form popup closes
			function (e:Event):void{

				var vm:CreateDisclosureFormPopupModel = e.currentTarget as CreateDisclosureFormPopupModel;
				var disclosureSetupInfo:DisclosureSetupInfo = new DisclosureSetupInfo();
				var closeEvent:NavigationEvent = new NavigationEvent(NavigationEvent.CLOSEVIEW,e.currentTarget as CreateDisclosureFormPopupModel);
				(parentContext as MVCController).dispatcher.dispatchEvent(closeEvent);

				if ( vm.createNewSelected )
				{
					disclosureSetupInfo.disclosureFormOption = DisclosureSetupInfo.CREATE_NEW;
				}
				if ( vm.cloneExistingSelected )
				{
					// form is editable
					disclosureSetupInfo.disclosureFormOption = DisclosureSetupInfo.CLONE;
					disclosureSetupInfo.sourceDisclosureId = vm.disclosureIDToCloneOrLinkFrom;
            		disclosureSetupInfo.complianceAlertResponse = "Y";
				}
				if ( vm.linkToExistingSelected )
				{
					// form in NON-editable
					disclosureSetupInfo.disclosureFormOption = DisclosureSetupInfo.LINK;
					disclosureSetupInfo.sourceDisclosureId = vm.disclosureIDToCloneOrLinkFrom;
            		disclosureSetupInfo.complianceAlertResponse = "Y";
				}
				createDisclosureForm(ratingShell,disclosureSetupInfo,newFormCreatedHandler);
			});

        	(parentContext as MVCController).dispatcher.dispatchEvent(new NavigationEvent(NavigationEvent.OPENVIEW,cdfpm));
		}

		public static function createDisclosureForm(ratingShell:RatingShell,dsi:DisclosureSetupInfo,newFormCreatedHandler:Function):void{
			RatingServiceProxy.getInstance().createDisclosure(ratingShell,dsi,newFormCreatedHandler);
		}

		//=======================================================================================================
		//=======================================================================================================
		// CORRECT THE FORM
		//=======================================================================================================
		//=======================================================================================================
		public static function onCorrectDisclosureForm(controller:MVCController,model:MVCModel,ratingShellId:Number):void{

			parentContext = controller;
			var dcsm:DisclosureCorrectionSetupModel = new DisclosureCorrectionSetupModel();
			dcsm.ratingShellId = ratingShellId;
			dcsm.context = model;

			if ( model.hasOwnProperty("ratingShellModel"))
			{
				var rs:RatingShell = model["ratingShellModel"] as RatingShell;
				dcsm.ratingShellDesc = rs.description;
				dcsm.disclosureIndicators = rs.disclosureIndicators;
				dcsm.caseObject = rs.kase;
			}else
			{
				throw new Error("expecting a srs or mrs viewmodel that has a ratingShellModel populated on it");
			}
			dcsm.addEventListener(Event.COMPLETE,openNewlyCreatedDisclosureCorrectionWorkItem);
			var navEv:NavigationEvent = new NavigationEvent(NavigationEvent.OPENVIEW,dcsm);
			(parentContext as MVCController).dispatcher.dispatchEvent(navEv);
		}
		public static function openNewlyCreatedDisclosureCorrectionWorkItem(e:Event):void{//should be DisclosureCorectionWorkItem - not object

			var dcsm:DisclosureCorrectionSetupModel = e.currentTarget as DisclosureCorrectionSetupModel;
			var dcm:DisclosureCorrectionModel = new DisclosureCorrectionModel();
			var disclosureCorrectionWorkItem:DisclosureCorrection = dcsm.newDisclosureCorrectionWorkItem;
			if ( disclosureCorrectionWorkItem == null ) PFGError.throw$("System has not generated Diclosure Correction Work Item correctly");
			dcm.context = dcsm.context;
			//close the SetupPopup
			var navCE:NavigationEvent = new NavigationEvent(NavigationEvent.CLOSEVIEW,dcsm);
			(parentContext as MVCController).dispatcher.dispatchEvent(navCE);

		   	dcm.source = disclosureCorrectionWorkItem;
		   	dcm.disclosureCorrectionModel = disclosureCorrectionWorkItem;
		   	dcm.context = dcsm.context;
			// 	pdtt00028083 - if this work item is being added to a closed case then that case status must be changed to "Active"
	   		var c:Case = dcsm.caseObject;
	   		if ( c.status && c.status.code == Case.STATUS_CODE_CLOSED )
	   		{
	   			//make the case active
	   			CaseServiceProxy.getInstance().reopenCase( c , function (o:Object=null):void{
	   				if ( o && o is Case ) c = o as Case;
	   			});
	   		}
			// open the new work item
			var navEv:NavigationEvent = new NavigationEvent(NavigationEvent.OPENVIEW,dcm,disclosureCorrectionWorkItem);
			(parentContext as MVCController).dispatcher.dispatchEvent(navEv);
		}



		//=======================================================================================================
		//=======================================================================================================
		// REMOVE THE FORM
		//=======================================================================================================
		//=======================================================================================================

		public static function onRemoveDisclosureForm(ratingShell:RatingShell,formRemovedHandler:Function):void
		{
			// 1st we make a service call to determine if this a child form linked to a parent
			// if it isnt then simply show message then remove
			// if it IS then we show a different message and do NOT remove
			RatingServiceProxy.getInstance().getRatingShellsLinkedByDisclosure(ratingShell.id,
				function (o:Object = null):void
				{
					if ( o )
					{
						if ( o is ArrayCollection )
						{
							if ( ( o as ArrayCollection ).length > 0 )
							{
								// there are linked forms so we show a message and have a hard stop to the flow here
								doNOTRemoveDisclosureFormLinkedToParentForm((o as ArrayCollection).length,ratingShell);
								return;
							}
						}
					}
					removeDisclosureFormNOTLinkedToParentForm(ratingShell,formRemovedHandler);
				});
		}
		public static function removeDisclosureFormNOTLinkedToParentForm(ratingShell:RatingShell,formRemovedHandler:Function):void{
			AlertUtil.show("Are you sure you want to remove the Regulatory Disclosure Form for this Rating Shell?\n\nContinuing will delete the disclosure form, but will not change the contents of the Rating Shell. Note that all credit rating actions require a disclosure form in order to continue with the Approval process.", null, "Are You Sure?", AlertUtil.YES|AlertUtil.CANCEL,null, null, "Remove Disclosure Form", null,
        		null, function(event:Event):void
        		{
        			// do some service call here to remove the disclosure form...
        			RatingServiceProxy.getInstance().removeDisclosure(ratingShell.id, ratingShell.disclosureId,formRemovedHandler);
				},null,175
        	);
		}
		public static function doNOTRemoveDisclosureFormLinkedToParentForm(numberOfLinkedShells:int,ratingShell:RatingShell):void{
			// display some error message and then do nothing
			AlertUtil.show("This Disclosure Form cannot be removed from its originating rating shell:\n"
			+ ratingShell.id.toString() + " - " + ratingShell.name + "\n\n"
			+ "There are " + numberOfLinkedShells.toString() + " Rating Shells linked to this Disclosure Form\n"
			+ "To locate these rating shells, please search for Rating Shell work items using Disclosure Form ID : " + ratingShell.disclosureDocumentNumber.toString(), null, "Disclosure Form Cannot Be Removed", AlertUtil.YES, null, null, "Close");
		}

		public static function autoCreateDisclosureForm(ratingShell:RatingShell, callback:Function):void
		{
			var disclosureID:Number;
			if ( ratingShell )
			{
				disclosureID = ratingShell.disclosureId;
			}
			if ( disclosureID == 0 || isNaN(disclosureID))
			{
				RatingServiceProxy.getInstance().isMechanicalWithdrawal(ratingShell.id, function(result:Boolean):void
				{
					if (result)
					{
						var dsi:DisclosureSetupInfo = new DisclosureSetupInfo();
						dsi.disclosureFormOption = DisclosureSetupInfo.CREATE_NEW;
						RatingServiceProxy.getInstance().createDisclosure(ratingShell, dsi, function(disclosure:Disclosure):void
						{
							callback(disclosure, true);
						});
					}
					else
					{
						callback(ratingShell.disclosure, false);
					}
				});
			}
			else
			{
				callback(ratingShell.disclosure, false);
			}
		}
		public static function disclosureFormsHaveChanged(currentForm:Disclosure,previousForm:Disclosure):Boolean{
			var formsHaveChanged:Boolean = false;
			if ( currentForm == null )
			{
				if ( previousForm == null )
				{
					return false;
				}else{
					return true;
				}
			}else{
				if ( previousForm != null )
				{
					// both are not null
					if ( previousForm.disclosureDocumentNumber != currentForm.disclosureDocumentNumber)
					{
						return true;
					}
					if ( previousForm.disclosureDocumentId != currentForm.disclosureDocumentId)
					{
						return true;
					}
					if ( previousForm.linked != currentForm.linked )
					{
						return true;
					}
					if ( currentForm.markedForRemoval )
					{
						return true;
					}
				}else{
					return true;
				}
			}
			return formsHaveChanged;
		}
		public static function disclosureAttributesHaveChanged(currentAttributes:DisclosureAttribute,previousAttributes:DisclosureAttribute):Boolean{
			var attributesHaveChanged:Boolean = false;
			if ( currentAttributes == null )
			{
				if ( previousAttributes == null )
				{
					return false;
				}else{
					return true;
				}
			}else{
				if ( previousAttributes != null )
				{
					// both are not null
					if ( previousAttributes.absIndicator != currentAttributes.absIndicator )
					{
						return true;
					}
					if ( previousAttributes.subsequentRatingIndicator != currentAttributes.subsequentRatingIndicator )
					{
						return true;
					}
				}else{
					return true;
				}
			}
			return attributesHaveChanged;
		}

	}
}