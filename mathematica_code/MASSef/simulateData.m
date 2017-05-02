(* ::Package:: *)

(* ::Title:: *)
(*simulateData*)


(* ::Section:: *)
(*Definitions*)


Begin["`Private`"];


(* ::Subsection:: *)
(*Calculate buffer ionic strength*)


calculateBufferIonicStrength[bufferInfo_, dataListFull_] := Block[{bufferData, localBuffInfo, localAcid, localBase, bufferIonStrength, ind1, ind2},
	(*Calculate Buffer Ionic Strength*)
	
	Which[StringQ[dataListFull[[1]][[1]]] && StringMatchQ[dataListFull[[1]][[1]],  RegularExpression["Ki.*"]] && Dimensions[dataListFull][[2]] == 12, ind1=7; ind2=9,
		  MemberQ[{11, 12}, Dimensions[dataListFull][[2]]], ind1=6; ind2=8, (* Km Data*)
	  	Dimensions[dataListFull][[2]] == 8, ind1=5; ind2=7, (* kcat data *)
	  	Dimensions[dataListFull][[2]] == 13, ind1=8; ind2=10];

	bufferData=Table[
		(*Assay Buffer Concentrations*)
		{entry[[ind2]],
		(*Buffer Information*)
		Table[
			Select[bufferInfo,#[[1,1]] == buffer[[1]]&][[1]], 
		{buffer,entry[[ind2]]}],
		(*Solution pH*)
		entry[[ind1]]},
	{entry, dataListFull}];

	bufferIonStrength=
		Table[
			{localBuffInfo = Select[bufferData[[buffer,2]], bufferData[[buffer,1,indBuff,1]] == #[[1,1]]&][[1]];
			{localBuffInfo, bufferData[[buffer,3]], bufferData[[buffer, 1, indBuff, 2]]};
			(* The Buffer concentratrations are calculated using a solved form of the Henderson-Hasselbach equation:
				Subscript[[HA], Ion]= Subscript[[HA], Total]/(1+10^(pH-pKa)) Subscript[and 
				[A^-], Ion]= Subscript[[HA], Total]-Subscript[[HA], Ion                     ]*)
			localAcid = (bufferData[[buffer,1,indBuff,2]](*Total Buffer*)/(1+10^(ToExpression[bufferData[[buffer,3]]](*pH*)-localBuffInfo[[2]](*pKa*))));
			(*Subscript[c, i]Subscript[z, i]^2*)
			localAcid*(localBuffInfo[[3]])^2,
			localBase = bufferData[[buffer,1,indBuff,2]]-localAcid;
			localBase*(localBuffInfo[[4]])^2},
		{buffer,bufferData//Length}, {indBuff,bufferData[[buffer,1]]//Length}];

	(*Ionic Strength = 1/2\[Sum]Subscript[c, i]Subscript[z, i]^2*)
	bufferIonStrength = Table[1/2*Total[Flatten[media]], {media,bufferIonStrength}];

	Return[bufferIonStrength];
];


(* ::Subsection:: *)
(*Calculate salt ionic strength*)


calculateSaltIonicStrength[ionCharge_, dataListFull_] := 
	Block[{localSaltCharge, saltIonStrength, ind},
	
	Which[StringQ[dataListFull[[1]][[1]]] && StringMatchQ[dataListFull[[1]][[1]],  RegularExpression["Ki.*"]] && Dimensions[dataListFull][[2]] == 12, ind=10,
	  	Dimensions[dataListFull][[2]]==11, ind=9,
	      Dimensions[dataListFull][[2]] == 12, ind=10,
		  Dimensions[dataListFull][[2]] == 8, ind=8];

	saltIonStrength=Table[
		localSaltCharge = Select[ionCharge,#[[1]] == salt[[1]]&][[1,2]];
		(*Subscript[c, i]Subscript[z, i]^2*)
		salt[[2]]*localSaltCharge^2,
	{entry, dataListFull}, {salt,entry[[ind]]}];

	(*Ionic Strength = 1/2\[Sum]Subscript[c, i]Subscript[z, i]^2*)
	saltIonStrength=Table[1/2*Total[Flatten[media]],{media,saltIonStrength}];

	Return[saltIonStrength];
];


calculateIonicStrength[dataListFull_, bufferInfo_, ionCharge_]:=Block[{bufferIonStrength, saltIonStrength, ionicStrength},

	bufferIonStrength = calculateBufferIonicStrength[bufferInfo, dataListFull];

	saltIonStrength = calculateSaltIonicStrength[ionCharge, dataListFull];

	ionicStrength = Thread[bufferIonStrength+saltIonStrength];

	Return[ionicStrength];
];


(* ::Subsection:: *)
(*Calculate adjusted Keq using equilibrator*)


calculateAdjustedKeq[rxn_, ionicStrength_, dataListFull_, bigg2equilibrator_] := Block[{adjustedKeqVal, ind},

	Which[StringQ[dataListFull[[1]][[1]]] && StringMatchQ[dataListFull[[1]][[1]],  RegularExpression["Ki.*"]] && Dimensions[dataListFull][[2]] == 12, ind=7,
		  MemberQ[{11, 12}, Dimensions[dataListFull][[2]]], ind=6,
		  Dimensions[dataListFull][[2]] == 8, ind=5];

	(*Calculate the Keq Using Equilibrator*)
	adjustedKeqVal=Table[
		dG2keq@Chop[calcDeltaG[{rxn}, bigg2equilibrator, is->ionicStrength[[entry]], pH->ToExpression[dataListFull[[entry,ind]]]]],
	{entry, dataListFull//Length}];
		
	Return[adjustedKeqVal];	
];


getDataListFull[rxn_, dataList_, dataListSub_] := Block[{char2met, dataListFull},
		
	char2met = getConversionChar2Met[rxn];
	dataListFull = dataList/.DeleteDuplicates[Flatten@{char2met,dataListSub}]; 
	
	Return[dataListFull];
];


getMinMaxPsDataVal[val_] := Block[{minPsDataVal, maxPsDataVal},
	minPsDataVal = Log10[val]-1;
	maxPsDataVal = Log10[val]+1;

	Return[{minPsDataVal, maxPsDataVal}];
];

minPsDataValFunc[Km_]:=Log10[Km]-1;
maxPsDataValFunc[Km_]:=Log10[Km]+1;


getMetSub[dataList_] := Block[{dataListSub},
	dataListSub=Table[
		{pt[[1]] -> m[pt[[1]],"c"], coSub[[1]] -> m[coSub[[1]],"c"]},
	{pt, dataList}, {coSub,pt[[4]]}]//Flatten//Union;

	Return[dataListSub];
];


removeMetsNotInReaction[rxn_, kmListFull_] := Block[{kmListFullLocal, entriesToDelete={}},
	Do[
		If[
			!MemberQ[Union[Cases[rxn, _metabolite,\[Infinity]]], kmListFull[[km,1]]],
			AppendTo[entriesToDelete, km];
		],
	{km, Length @ kmListFull}];
	
	kmListFullLocal = Delete[kmListFull, entriesToDelete];
	
	Return[kmListFullLocal];
];


handleCosubstrateData[dataListFull_, metsFull_, metSatForSub_, metSatRevSub_, dataRange_, assumedSaturatingConc_, rxn_] := 
	Block[{dataCoSub, dataListFullLocal, coSubList={}, indicies, dataCoSubFull},

	(*Handle CoSubstrates*)
	dataCoSub = Table[pt[[4]], {pt,dataListFull}];
	dataListFullLocal = Map[ReplacePart[#, 4->Table[{met}, {met,metsFull}]]&, dataListFull];

	(*Extract CoSubstrates*)
	Do[
		If[
			(*True: Is a Reactant*)
			MemberQ[metSatForSub[[All,1]], pt[[1]]],
			indicies = Position[Flatten @ metsFull, pt[[1]]];(*Subject Metabolite Index*)
			Map[AppendTo[indicies, Flatten[Position[Flatten @ metsFull,#],1]]&, metSatRevSub[[All,1]]];(*Relative Product Indices*)
			indicies = DeleteCases[indicies, {}];
			AppendTo[coSubList, Delete[Flatten @ metsFull,indicies]];,
			
			(*False: Is a Product*)
			indicies = Position[Flatten @ metsFull, pt[[1]]];(*Subject Metabolite Index*)
			Map[AppendTo[indicies, Flatten[Position[Flatten @ metsFull, #],1]]&, metSatForSub[[All,1]]];(*Relative Product Indices*)
			indicies = DeleteCases[indicies, {}];
			AppendTo[coSubList, Delete[Flatten @ metsFull, indicies]];
		],
	{pt, dataListFullLocal}];

	(*Append the Pseudo-Data Concentrations for Substrate*)
	Do[
		AppendTo[
			dataListFullLocal[[pt,4,Position[dataListFullLocal[[pt,4]],dataListFullLocal[[pt,1]]][[1,1]]]], 
			dataRange[[pt]]],
	{pt, Length @ dataListFullLocal}];
	Print[dataListFullLocal];
	Print[coSubList];
	(*Handle CoSubstrate Data*)
	dataCoSubFull=
		Table[
			Print[dataListFullLocal[[pt]]];
			Print[coSubList[[pt]]];
			Print[dataCoSub[[pt,All,1]]];
			Print[coSubList[[pt,met]]];
			
			Which[
				(*CoSubstrate is Present in Data and Has a Data Value*)
				MemberQ[dataCoSub[[pt,All,1]],coSubList[[pt,met]]] && NumberQ[Select[dataCoSub[[pt]],#[[1]]==coSubList[[pt,met]]&][[1,2]]],
					Print["1"];
					(*Extract CoSubstrate Concentration and Repeat It for Each Data Point*)
					{Select[dataCoSub[[pt]],#[[1]]==coSubList[[pt,met]]&][[1,1]],
					Table[
						Select[dataCoSub[[pt]],#[[1]]==coSubList[[pt,met]]&][[1,2]],
					{dataRange[[pt]]//Length}]
				},
				(*CoSubstrate is Present in Data but Does not Have a Data Value*)
				MemberQ[dataCoSub[[pt,All,1]], coSubList[[pt,met]]] && !NumberQ[Select[dataCoSub[[pt]],#[[1]]==coSubList[[pt,met]]&][[1,2]]],
				Print["2"];
					(*Use an Assumed Concentration and Repeat It for Each Data Point*)
					{Select[dataCoSub[[pt]],#[[1]]==coSubList[[pt,met]]&][[1,1]],
					Table[
						assumedSaturatingConc,
					{Length @ dataRange[[pt]]}]
				},
				(*CoSubstrate is Not Present in Data and is not a substrate nor product *)
				!MemberQ[dataCoSub[[pt,All,1]],coSubList[[pt,met]]] && !MemberQ[dataCoSub[[pt,All,1]], Flatten@{getSubstrates[rxn],getProducts[rxn]}],
				Print["3"];
				(*Use an Assumed Concentration and Repeat It for Each Data Point*)
					{coSubList[[pt,met]],
					Table[
						0,
					{Length @ dataRange[[pt]]}]
				},
				(*CoSubstrate is Not Present in Data but is a substrate or product*)
				!MemberQ[dataCoSub[[pt,All,1]],coSubList[[pt,met]]],
				Print["4"];
				(*Use an Assumed Concentration and Repeat It for Each Data Point*)
					{coSubList[[pt,met]],
					Table[
						assumedSaturatingConc,
					{Length @ dataRange[[pt]]}]
				}
				]
				Print["------"];,
		{pt, Length @ coSubList},{met, Length @ coSubList[[pt]]}];

    (*Append All Remaining CoSubstrate Concentrations to 'dataListFullLocal'*)
	Do[
		Which[
			MemberQ[Flatten @ dataCoSubFull[[pt]], dataListFullLocal[[pt,4,met,1]]],
			
			(*True: Concentration Values from Data*)
			dataListFullLocal[[pt,4,met]]={dataListFullLocal[[pt,4,met,1]],
			Select[dataCoSubFull[[pt]],#[[1]]==dataListFullLocal[[pt,4,met,1]]&][[1,2]]},
			
			(*False: All Concentration Values Zero*)
			!MemberQ[Flatten @ dataCoSubFull[[pt]], dataListFullLocal[[pt,4,met,1]]] && !MatchQ[dataListFullLocal[[pt,4,met,1]], dataListFullLocal[[pt,1]]],
			
			(*Non Pseudo-Data Values*)
			dataListFullLocal[[pt,4,met]]={dataListFullLocal[[pt,4,met,1]],
			Table[0, {Length @ dataRange[[pt]]}]}

		],
	{pt, Length @ dataListFullLocal},{met, Length @ dataListFullLocal[[pt,4]]}];

	Return[dataListFullLocal];
];


correctChemicalActivities[dataListFull_, metsFull_, activeIsoSub_, ionicStrength_] := 
	Block[{assayMet, assayCond},
	
	assayMet = Map[Transpose[#[[All,2]]]&, dataListFull[[All,4]]];
	assayCond = Map[Transpose[#]&, dataListFull[[All,6;;7]]];

	assayMet=
		Table[(* chemical activity = \[Gamma]*[(S^z)] *)
		((*Exp[activityCoefficient[[All,2]]]**)activeIsoSub[[All,2]])/.
			Thread[metsFull->assayMet[[met,pt]]]/.
			parameter["IonicStrength"]->ionicStrength[[met]]/.
			parameter["pH"]->ToExpression[assayCond[[met,pt,1]]],
		{met, Length @ assayMet},{pt, Length @ assayMet[[met]]}];

	assayMet = Flatten[assayMet, 1];
	assayCond = Flatten[assayCond, 1];
	
	Return[{assayMet, assayCond}];
];


(* ::Subsection:: *)
(*Simulate Km data*)


simulateKmData[rxn_, metsFull_, metSatForSub_, metSatRevSub_, kmList_, otherParmsList_, assumedSaturatingConc_, eTotal_,
			   logStepSize_, activeIsoSub_, bufferInfo_, ionCharge_, inputPath_, fileList_, KeqVal_:Null, bigg2equilibrator_:Null] := 
	Block[{kmEqn, kmListSub, char2met, kmListFull, dataRange, vValues,   
			ionicStrength, adjustedKeqVal, assayMet, assayCond, fileFlagList, vList, kmFittingData},

	(*Michaelis-Menten Equation*)
	kmEqn[S_,Km_]:=S/(Km+S);

	(*Change Character Metabolite Names Into MASS toolbox Metabolite Notation. 
	NOTE: You may have to add some metabolites in for unusual assay conditions*)
	kmListSub = getMetSub[kmList];

	kmListFull = getDataListFull[rxn, kmList, kmListSub];

	(*Parse Km Values Where the Substrate is Not in the Primary Reaction*)
	kmListFull = removeMetsNotInReaction[rxn, kmListFull];

	(*Generate Data Points (An Order of Magnitude Above and Below the Km's)*)
	dataRange=
		Table[
			{i, km[[2]]},
		{km, kmListFull}, {i,minPsDataValFunc[km[[2]]], maxPsDataValFunc[km[[2]]],logStepSize}];

	(*Generate Resultant Rates*)
	vValues=Table[
		kmEqn[10^dataPt[[1]],dataPt[[2]]],
	{dataSet,dataRange},{dataPt,dataSet}];

	(*Switch Data to Euclidean Space and Append to the Km List*)
	dataRange=10^#[[All,1]]&/@dataRange;
	kmListFull=Table[Append[kmListFull[[km]],vValues[[km]]],{km,Length[kmListFull]}];

	(*Match to Comparision Equations*)
	Do[
		If[StringMatchQ[path, RegularExpression[".*relRate.*_" <> kmListFull[[km,1,1]]<>"\\.txt"]],
			AppendTo[kmListFull[[km]], FileNameJoin[Flatten@{"\""<>inputPath, StringCases[StringReplace[path, "\\" -> "/"], RegularExpression[StringReplace[inputPath, "\\" -> "/"] <> "(.*)"] -> "$1"]<>"\""}, OperatingSystem-> $OperatingSystem]]
		],
		{km, Length @ kmListFull}, {path,fileList}];

	kmListFull = handleCosubstrateData[kmListFull, metsFull, metSatForSub, metSatRevSub, dataRange, assumedSaturatingConc, rxn];

	ionicStrength = calculateIonicStrength[kmListFull, bufferInfo, ionCharge];
	Print[ionicStrength];
	adjustedKeqVal= 
		If[NumericQ[KeqVal],	
			ConstantArray[{Keq[getID[rxn]]-> KeqVal}, Dimensions[kmListFull][[1]]],
			calculateAdjustedKeq[rxn, ionicStrength, kmListFull, bigg2equilibrator]
		];	

	adjustedKeqVal=
	Table[
		adjustedKeqVal[[km]], 
	{km, Length @ adjustedKeqVal}, {Length @ dataRange[[km]]}]//Flatten;

	(*Repeat Assay Conditions for Each Data Point*)
	Do[
		kmListFull[[km,con]] = Table[kmListFull[[km,con]], {rep, Length @  dataRange[[km]]}],
	{km, Length @ kmListFull},{con, 6, 7}];

	(*Assemble Fitting Data*)

	(*Correct Chemical Activites*)
	{assayMet, assayCond} = correctChemicalActivities[kmListFull, metsFull, activeIsoSub, ionicStrength];

	(*End Correct Chemical Activites*)
	fileFlagList=Flatten[Table[kmListFull[[km,-1]], {km, Length @ kmListFull}, {Length @ dataRange[[km]]}]];
	vList=Flatten[kmListFull[[All,-2]]];(*Target Data*)

	(*this section is identical to kcat simulation - create a common function later*)
	kmFittingData=
		Table[
			Join[Append[assayMet[[pt]],eTotal], assayCond[[pt]]],
		{pt, Length @ assayMet}];
	kmFittingData=
		Table[
			Join[kmFittingData[[pt]], {fileFlagList[[pt]],vList[[pt]]}],
		{pt, Length @ kmFittingData}];
			
	kmFittingData=Table[
		Join[{adjustedKeqVal[[pt,2]]}, kmFittingData[[pt]]],
	{pt, Length @ kmFittingData}];

	Return[kmFittingData];
];


(* ::Subsection:: *)
(*Simulate S05 data*)


simulateS05Data[rxn_, metsFull_, metSatForSub_, metSatRevSub_, s05List_, otherParmsList_, assumedSaturatingConc_, eTotal_,
			   logStepSize_, activeIsoSub_, bufferInfo_, ionCharge_, inputPath_, fileList_, KeqVal_:Null, bigg2equilibrator_:Null] := 
	Block[{hillEqn, s05MetSub, char2met, hillList, s05ListFull, dataRange, vValues, 
			ionicStrength, adjustedKeqVal, assayMet, assayCond, fileFlagList, vList, s05FittingData},

	(*Hill Equation*)
	hillEqn[S_,s05_,n_]:=S^n/(s05^n+S^n);

	(*Incorporate Hill Values*)
	s05ListFull=s05List;
	hillList = Select[otherParmsList,#[[1]]=="n"&];

	Which[Length[hillList] == 0,
		(*If there's no data for n, just consider it to be 1*)
		s05ListFull = Insert[#, 1, 9] & /@ s05ListFull,
		Length[hillList] == 1,
		
		(*True: There is only one hill value for the enzyme*)
		s05ListFull = Insert[#, hillList[[1, 3]], 9] & /@ s05ListFull,
		
		Length[hillList] > 2,
		(*False: The hill values are substrate specific*)
		s05ListFull = 
			Table[
				Insert[s05, Select[hillList, #[[2]] == s05[[1]] &][[1, 3]], 9],
			{s05, s05ListFull}];
	];

	(*Change Character Metabolite Names Into MASS toolbox Metabolite Notation. 
	NOTE: You may have to add some metabolites in for unusual assay conditions*)
	s05MetSub = getMetSub[s05List];
	
	s05ListFull = getDataListFull[rxn, s05ListFull, s05MetSub];

	(*Parse s05 Values Where the Substrate is Not in the Primary Reaction*)
	s05ListFull = removeMetsNotInReaction[rxn, s05ListFull];

	(*Generate Data Points (An Order of Magnitude Above and Below the s05's)*)
	dataRange=
		Table[
			{i, s05[[2]], s05[[9]]},
		{s05,s05ListFull},{i, minPsDataValFunc[s05[[2]]], maxPsDataValFunc[s05[[2]]], logStepSize}];
		
	(*Generate Resultant Rates*)
	vValues=
		Table[
			hillEqn[10^dataPt[[1]],dataPt[[2]],dataPt[[3]]],
		{dataSet,dataRange},{dataPt,dataSet}];

	(*Switch Data to Euclidean Space and Append to s05 the List*)
	dataRange = Map[10^#[[All,1]]&, dataRange];
	s05ListFull = Table[Append[s05ListFull[[s05]], vValues[[s05]]], {s05, Length @ s05ListFull}];

	(*Match to Comparision Equations*)
	Do[
		If[StringMatchQ[path, RegularExpression[".*_" <> s05ListFull[[s05, 1, 1]]<>"\\.txt"]],
			AppendTo[s05ListFull[[s05]], FileNameJoin[Flatten@{"\""<>inputPath, StringCases[StringReplace[path, "\\" -> "/"], RegularExpression[StringReplace[inputPath, "\\" -> "/"] <> "(.*)"] -> "$1"]<>"\""}, OperatingSystem-> $OperatingSystem]]
		],
	{s05, Length @ s05ListFull}, {path,fileList}];

	(*Handle CoSubstrates*)
	s05ListFull = handleCosubstrateData[s05ListFull, metsFull, metSatForSub, metSatRevSub, dataRange, assumedSaturatingConc, rxn];

	ionicStrength = calculateIonicStrength[s05ListFull, bufferInfo, ionCharge];

	adjustedKeqVal= 
		If[NumericQ[KeqVal],	
			ConstantArray[{Keq[getID[rxn]]-> KeqVal}, Dimensions[s05ListFull][[1]]],
			calculateAdjustedKeq[rxn, ionicStrength, s05ListFull, bigg2equilibrator]
		];	

	adjustedKeqVal=
		Table[
			adjustedKeqVal[[s05]], 
		{s05, Length @ adjustedKeqVal}, {Length @ dataRange[[s05]]}]//Flatten;

	(*Repeat Assay Conditions for Each Data Point*)
	Do[
		s05ListFull[[s05,con]] = Table[s05ListFull[[s05,con]], {rep, Length @ dataRange[[s05]]}],
	{s05,s05ListFull//Length},{con,6,7}];

	(*Assemble Fitting Data*)
	(*Correct Chemical Activites*)
	{assayMet, assayCond} = correctChemicalActivities[s05ListFull, metsFull, activeIsoSub, ionicStrength];

	(*End Correct Chemical Activites*)
	
	fileFlagList=Flatten[Table[s05ListFull[[s05,-1]], {s05, Length @ s05ListFull}, {Length @ dataRange[[s05]]}]];
	
	vList=Flatten[s05ListFull[[All,-2]]];(*Target Data*)
	
	s05FittingData=Table[Join[Append[assayMet[[pt]],eTotal], assayCond[[pt]]], {pt, Length @ assayMet}];
	
	s05FittingData=
		Table[
			Join[s05FittingData[[pt]], {fileFlagList[[pt]],vList[[pt]]}], 
		{pt, Length @ s05FittingData}];
		
	s05FittingData=Table[Join[{adjustedKeqVal[[pt,2]]},s05FittingData[[pt]]],{pt, Length @ s05FittingData}];
	
	Return[s05FittingData];
];


(* ::Subsection:: *)
(*Simulate kcat data*)


simulateKcatData[rxn_, metsFull_, metSatForSub_, metSatRevSub_, kcatList_, otherParmsList_, assumedSaturatingConc_, eTotal_,
			  logStepSize_, nonKmParamWeight_, activeIsoSub_, bufferInfo_, ionCharge_, inputPath_,
			  fileList_, KeqVal_:Null, bigg2equilibrator_:Null] := 
	Block[{vMaxEqn, kcatListSub, char2met, kcatListFull, vValues, localMets,  coSubData, coSub, localConc,
			ionicStrength, adjustedKeqVal, assayMet, assayCond, fileFlagList, vList, kcatFittingData,
			substrateCheck},

	(*Vmax Equation*)
	vMaxEqn[kcat_]:=kcat*eTotal;

	(*Change Character Metabolite Names Into MASS toolbox Metabolite Notation. 
	NOTE: You may have to add some metabolites in for unusual assay conditions*)
	kcatListSub = #->m[#,"c"]&/@Union[Flatten[kcatList[[All,1,All,1]]]];		
	
	kcatListFull = getDataListFull[rxn, kcatList, kcatListSub];

	(*Generate Target Data Points and Repeat the Values for Weighting During the Fitting Process*)
	vValues = Table[
			vMaxEqn[#[[2]]],
		{nonKmParamWeight}]&/@kcatList;

	(*Match the Data Type to the Target Equation and Repeat the Output for Each Data Point*)
	fileFlagList=
		Table[
			(*Check if the Metabolites Substrates*)
			substrateCheck=MemberQ[getSubstrates[rxn],#]&/@kcatListFull[[kcat,1,All,1]];
			If[
				(*If any of the metabolites are substrates, this returns True*)
				Or @@ substrateCheck,
				(*True: kcat is for the Forward Reaction*)
				FileNameJoin[{"\""<>inputPath, "absRateFor.txt"<>"\""}, OperatingSystem->$OperatingSystem],
				(*True: kcat is for the Reverse Reaction*)
				FileNameJoin[{"\""<>inputPath, "absRateRev.txt"<>"\""}, OperatingSystem->$OperatingSystem]
			],
		{kcat,kcatListFull//Length}, {nonKmParamWeight}];
	
	(*Handle Metabolite Values. NOTE: Available metabolite concentrations are auto-converted from mM to M*)
	localMets={#}&/@metsFull;
	coSubData=
		Table[
			Select[kcat,#[[2]]!="Null"&],
		{kcat,kcatListFull[[All,1]]}];

	coSub = 
		Table[
			(*Check if the Metabolites Substrates*)
			substrateCheck=MemberQ[getSubstrates[rxn],#]&/@kcatListFull[[kcat,1,All,1]];
			If[
				(*If any of the metabolites are substrates, this returns True*)
				Or @@ substrateCheck,
				(*True: kcat is for the Forward Reaction*)
				Table[
					Which[
						(*Concentration Data is Available*)
						MemberQ[coSubData[[kcat]][[All,1]],met],
						localConc=Select[coSubData[[kcat]],#[[1]]==met&][[1]];
						{met, Table[localConc[[2]],{nonKmParamWeight}]},

						(*Is a Reactant and Concentration Data is Not Available*)
						MemberQ[metSatForSub[[All,1]],met]&&!MemberQ[coSubData[[kcat]][[All,1]],met],
						{met,Table[assumedSaturatingConc,{nonKmParamWeight}]},
						(*Is a Product and Concentration Data is Not Available*)
						!MemberQ[metSatForSub[[All,1]],met]&&!MemberQ[coSubData[[kcat]][[All,1]],met],
						{met,Table[0,{nonKmParamWeight}]}
				],{met,localMets[[All,1]]}],
			(*False: kcat is for the Reverse Reaction*)
			Table[
				Which[
					(*Concentration Data is Available*)
					MemberQ[coSubData[[kcat]][[All,1]],met],
					localConc=Select[coSubData[[kcat]],#[[1]]==met&][[1]];
					{met,Table[localConc[[2]],{nonKmParamWeight}]},
					(*Is a Reactant and Concentration Data is Not Available*)
					MemberQ[metSatRevSub[[All,1]],met]&&!MemberQ[coSubData[[kcat]][[All,1]],met],
					{met,Table[assumedSaturatingConc,{nonKmParamWeight}]},
					(*Is a Product and Concentration Data is Not Available*)
					!MemberQ[metSatRevSub[[All,1]],met]&&!MemberQ[coSubData[[kcat]][[All,1]],met],
					{met,Table[0,{nonKmParamWeight}]}
				],{met,localMets[[All,1]]}]
		], {kcat,kcatListFull//Length}];

	(*Replace Data Metabolites with Full CoSubstrates*)
	kcatListFull=
		Table[
			ReplacePart[kcatListFull[[kcat]],1->coSub[[kcat]]],
		{kcat, Length @ kcatListFull}];

	ionicStrength = calculateIonicStrength[kcatListFull, bufferInfo, ionCharge];

	adjustedKeqVal= 
		If[NumericQ[KeqVal],	
			ConstantArray[{Keq[getID[rxn]]-> KeqVal}, Dimensions[kcatListFull][[1]]],
			calculateAdjustedKeq[rxn, ionicStrength, kcatListFull, bigg2equilibrator]
		];	
	adjustedKeqVal = 
		Table[
			adjustedKeqVal[[kcat]],{kcat, Length @ adjustedKeqVal},
		{i,nonKmParamWeight}] //Flatten;
	
	(*Assemble Fitting Data*)
	(*Correct Chemical Activites*)
	assayMet=Transpose[#[[All,2]]]&/@coSub;
	assayCond=Table[#[[5;;6]],{nonKmParamWeight}]&/@kcatListFull;
	assayMet=
		Table[(* chemical activity = \[Gamma]*[(S^z)] *)
			((*Exp[activityCoefficient[[All,2]]]**)activeIsoSub[[All,2]])/.
			Thread[metsFull->assayMet[[met,pt]]]/.
			parameter["IonicStrength"]->ionicStrength[[met]]/.
			parameter["pH"]->ToExpression[assayCond[[met,pt,1]]],
		{met,assayMet//Length},{pt, Length @ assayMet[[met]]}];

	assayMet=Flatten[assayMet,1];
	assayCond=Flatten[assayCond,1];
	(*End Correct Chemical Activites*)
	vValues = Flatten @ vValues;
	fileFlagList = Flatten @ fileFlagList;
	
	kcatFittingData=
		Table[
			Join[assayMet[[kcat]], Flatten @ {eTotal,assayCond[[kcat]],fileFlagList[[kcat]],vValues[[kcat]]}],
		{kcat, Length @ assayMet}];
	
	kcatFittingData=
		Table[
			Prepend[kcatFittingData[[pt]],adjustedKeqVal[[pt,2]]],
		{pt, Length @ kcatFittingData}];
	
	
	Return[kcatFittingData];
];


(* ::Subsection:: *)
(*Simulate inhibition data*)


fittingCompetitiveInhibEq[S_, I_, Km_, Kic_] := S / (Km*(1+(I/Kic)) +S);
fittingUnCompetitiveInhibEq[S_, I_, Km_, Kiu_] := S / (Km + S*(1+(I/Kiu)));
fittingNonCompetitiveInhibEq[S_, I_, Km_, Kic_, Kiu_] := S / (Km*(1+(I/Kic)) + S*(1+(I/Kiu)));

getInhibFlux[paramType_, paramList_] := Block[{flux},

	flux = Which[StringMatchQ[paramType, "Kic"],
			 	Apply[fittingCompetitiveInhibEq, paramList],
			 	StringMatchQ[paramType, "Kiuc"],
			 	Apply[fittingUnCompetitiveInhibEq, paramList],
			 	StringMatchQ[paramType, {"Kinc", "Kincc", "Kincu"}],
			 	Apply[fittingNonCompetitiveInhibEq, Flatten@paramList]
			 ];

	Return[flux];
];			 	


simulateInhibData[rxn_, metsFull_, metSatForSub_, metSatRevSub_, inhibList_, kmList_, assumedSaturatingConc_, eTotal_,
			   logStepSize_, activeIsoSub_, bufferInfo_, ionCharge_, inputPath_, fileList_, KeqVal_:{}] := 
	Block[{inhibListSub, char2met, inhibListFull, dataRange, vValues, dataCoSub, coSubList={}, indicies, dataCoSubFull, 
			ionicStrength, adjustedKeqVal, assayMet, assayCond, fileFlagList, vList, inhibFittingData, kmValues,
			inhibConcMultiplierList, substrateDataRange, inhibDataRange, inhibitor, paramType, otherInhib, KiOrder,res},

	(*Change Character Metabolite Names Into MASS toolbox Metabolite Notation. 
	NOTE: You may have to add some metabolites in for unusual assay conditions*)

	inhibListSub = Table[
		{entry[[2]] -> m[entry[[2]], "c"], coSub -> m[coSub,"c"]}, 
	{entry, inhibList}, {coSub, entry[[5]][[All,1]]}] // Flatten // Union;

	inhibListFull = getDataListFull[rxn, inhibList, inhibListSub];

	(*Parse Km Values Where the Substrate is Not in the Primary Reaction
	Do[
		If[
			!MemberQ[Union[Cases[rxn,_metabolite,\[Infinity]]],kmListFull[[km,1]]],
			otherParmsList=Append[otherParmsList,Prepend[kmListFull[[km]],"Km"]]//Union;(*Move Km param to otherParams*)
			kmListFull=Delete[kmListFull,km];
		],
	{km,Length[kmListFull]}];*)

	kmValues = Map[metabolite[#[[1]], "c"] -> #[[2]]&, kmList];

	inhibListFull = Table[

		Which[StringMatchQ[inhib[[1]], {"Kic", "Kiuc", "Kinc"}],
			  Delete[inhib,4],
			  
			  StringMatchQ[inhib[[1]], {"Kincc", "Kincu"}],
			  inhibitor = inhib[[2]];
			  paramType = inhib[[1]];
			  
			  otherInhib = Table[
								If[ (SameQ[inhibitor, inhibTemp[[2]]]) && (StringMatchQ[inhibTemp[[1]], {"Kincc", "Kincu"}]) &&(!StringMatchQ[paramType, inhibTemp[[1]]]),
								inhibTemp],
							{inhibTemp, inhibListFull}];

			   otherInhib = Flatten@DeleteCases[otherInhib, Null];
			   
			   KiOrder = If[ (StringMatchQ[otherInhib[[1]], "Kincc"]) && (StringMatchQ[inhib[[1]], "Kincu"]),
							{otherInhib[[3]], inhib[[3]]},
							{inhib[[3]], otherInhib[[3]]}
						];

			   {"Kinc", inhibitor, KiOrder,  inhib[[5]], inhib[[6]], inhib[[7]], inhib[[8]], inhib[[9]], inhib[[10]], inhib[[11]]}		  		  
		],
	{inhib, inhibListFull}];

	inhibListFull = DeleteDuplicates[inhibListFull];
	
	inhibConcMultiplierList = {0.5, 1, 2.};
		
	dataRange=
		Table[

			If [ Length[inhib[[3]]] > 1,
				{inhib[[1]], {10^s, inhibMultiplier*Mean[inhib[[3]]], inhib[[5,1,4]]/. kmValues, inhib[[3]]}},
				{inhib[[1]], {10^s, inhibMultiplier*inhib[[3]], inhib[[5,1,4]]/. kmValues, inhib[[3]]}}
			],
		{inhib, inhibListFull}, {inhibMultiplier, inhibConcMultiplierList}, {s, Log10[inhib[[5,1,4]]/. kmValues]-1, Log10[inhib[[5,1,4]]/. kmValues]+1, logStepSize}];
	

	vValues = 
		Table[
			Apply[getInhibFlux, dataPt],
			(*inhibEqn[10^dataPt[[1]], dataPt[[2]], dataPt[[3]], dataPt[[4]]]*)
		{dataPerInhib, dataRange}, {dataSet,dataPerInhib}, {dataPt,dataSet}];

	(*Switch Data to Euclidean Space and Append to the Km List*)
	substrateDataRange = Map[Map[#[[All,2]][[All,1]]&, #]&, dataRange];	
	inhibDataRange = Map[Map[#[[All,2]][[All,2]]&, #]&, dataRange];
	
	inhibListFull = 
		Table[
			Append[inhibListFull[[inhib]], vValues[[inhib]]],
		{inhib, Length @ inhibListFull}];

	(*Match to Comparision Equations*)	
	Do[
		If[MemberQ[Flatten[{getSubstrates[rxn], getProducts[rxn]}], inhibListFull[[inhib]][[2]]],
			AppendTo[inhibListFull[[inhib]], "\""<>Flatten[DeleteCases[StringCases[fileList, RegularExpression[".*inhib.*" <> getID@inhibListFull[[inhib]][[2]] <> ".txt"]], {}]][[1]] <>"\""],			
			
			If[MemberQ[getSubstrates[rxn], inhibListFull[[inhib]][[5, 1, 4]]],
				AppendTo[inhibListFull[[inhib]], FileNameJoin[{"\""<>inputPath, "absRateFor.txt"<>"\""}, OperatingSystem->$OperatingSystem]],
				AppendTo[inhibListFull[[inhib]], FileNameJoin[{"\""<>inputPath, "absRateRev.txt"<>"\""}, OperatingSystem->$OperatingSystem]]
			]
		],
	{inhib, Length @ inhibListFull}];

	
	(*Handle CoSubstrates*)
	dataCoSub = Table[inhib[[4]], {inhib, inhibListFull}];
	inhibListFull = ReplacePart[#, 4->Table[{met}, {met, metsFull}]]& /@ inhibListFull;

	(*Extract CoSubstrates*)
	Do[
		Which[MemberQ[metSatForSub[[All,1]], inhib[[5,1,4]]],
				(* Is a Reactant*)
				indicies = Position[Flatten @ metsFull, inhib[[5,1,4]]];(*Subject Metabolite Index*)
				AppendTo[indicies, Flatten[Position[Flatten @ metsFull,#],1]]& /@ metSatRevSub[[All,1]];(*Relative Product Indices*)
				AppendTo[coSubList, Delete[Flatten @ metsFull,indicies]];,
			MemberQ[metSatRevSub[[All,1]], inhib[[5,1,4]]],
				(*Is a Product*)
				indicies = Position[Flatten @ metsFull,inhib[[5,1,4]]];(*Subject Metabolite Index*)
				AppendTo[indicies, Flatten[Position[Flatten @ metsFull, #],1]]& /@ metSatForSub[[All,1]];(*Relative Product Indices*)
				AppendTo[coSubList, Delete[Flatten @ metsFull,indicies]];
		],
	{inhib,inhibListFull}];

	(*Append the Pseudo-Data Concentrations for Substrate*)
	Do[
		AppendTo[		
			inhibListFull[[inhib, 4, Position[inhibListFull[[inhib, 4]], inhibListFull[[inhib, 5, 1, 4]]][[1,1]]]], 
			substrateDataRange[[inhib]]];
		AppendTo[		
			inhibListFull[[inhib, 4, Position[inhibListFull[[inhib, 4]], inhibListFull[[inhib, 2]]][[1,1]]]], 
			inhibDataRange[[inhib]]],
	{inhib, Length @ inhibListFull}];

	(*Handle CoSubstrate Data*)
	dataCoSubFull=
		Table[
			Which[
				(*CoSubstrate is Present in Data and Has a Data Value*)
				MemberQ[dataCoSub[[inhib,All,1]], coSubList[[inhib,met]]] && NumberQ[Select[dataCoSub[[inhib]],#[[1]]==coSubList[[inhib,met]] &][[1,2]]],
					(*Extract CoSubstrate Concentration and Repeat It for Each Data Point*)
					{Select[dataCoSub[[inhib]],#[[1]]==coSubList[[inhib,met]]&][[1,1]],
					Table[
						Select[dataCoSub[[inhib]],#[[1]]==coSubList[[inhib,met]]&][[1,2]],
					{dataSet, substrateDataRange[[inhib]]}, {Length@dataSet}]
				},
				(*CoSubstrate is Present in Data but Does not Have a Data Value*)
				MemberQ[dataCoSub[[inhib,All,1]],coSubList[[inhib,met]]] && !NumberQ[Select[dataCoSub[[inhib]],#[[1]]==coSubList[[inhib,met]]&][[1,2]]],
					(*Use an Assumed Concentration and Repeat It for Each Data Point*)
					{Select[dataCoSub[[inhib]],#[[1]]==coSubList[[inhib,met]]&][[1,1]],
					Table[
						assumedSaturatingConc,
					{dataSet,  substrateDataRange[[inhib]]}, {Length@dataSet}]
				},
				(*CoSubstrate is Not Present in Data*)
				!MemberQ[dataCoSub[[inhib, All, 1]], coSubList[[inhib, met]]],
				(*Use an Assumed Concentration and Repeat It for Each Data Point*)
					{coSubList[[inhib, met]], 
					Table[
						assumedSaturatingConc, 
					{dataSet,  substrateDataRange[[inhib]]}, {Length@dataSet}]}
				],

		{inhib, Length @ coSubList},  {met, Length @ coSubList[[inhib]]}];

    (*Append All Remaining CoSubstrate Concentrations to 'kmListFull'*)
	Do[
		Which[
			MemberQ[Flatten @ dataCoSubFull[[inhib]], inhibListFull[[inhib, 4, met, 1]]] && Length@inhibListFull[[inhib, 4, Position[inhibListFull[[inhib, 4]], inhibListFull[[inhib, 4, met, 1]]][[1,1]]]] == 1,
			
			(*True: Concentration Values from Data*)
			inhibListFull[[inhib,4,met]] = {inhibListFull[[inhib,4,met,1]],
											Select[dataCoSubFull[[inhib]], #[[1]] == inhibListFull[[inhib,4,met,1]]&][[1,2]]},
			
			(*False: All Concentration Values Zero*)
			!MemberQ[Flatten @ dataCoSubFull[[inhib]], inhibListFull[[inhib,4,met,1]]] && Length@inhibListFull[[inhib,4,met]] <= 1,
			(*Non Pseudo-Data Values*)
			inhibListFull[[inhib,4,met]] = {inhibListFull[[inhib,4,met,1]],
											Table[0, {dataSet,  substrateDataRange[[inhib]]}, {Length@dataSet}]}
			
			(* Inhibitor, value: inhibition constant 
			MatchQ[inhibListFull[[inhib, 4, met, 1]], inhibListFull[[inhib, 2, 1, 1]]],
			inhibListFull[[inhib,4,met]] = {inhibListFull[[inhib,4,met,1]],
			Table[inhibListFull[[inhib, 2, 1, 2]], {Length @ substrateDataRange[[inhib]]}]}*)

		],
	{inhib, Length @ inhibListFull},{met, Length @ inhibListFull[[inhib,4]]}];

	ionicStrength = calculateIonicStrength[inhibListFull, bufferInfo, ionCharge];

	adjustedKeqVal= 
		If[NumericQ[KeqVal],	
			ConstantArray[{Keq[getID[rxn]]-> KeqVal}, Dimensions[inhibListFull][[1]]],
			calculateAdjustedKeq[rxn, ionicStrength, inhibListFull]
		];	

	adjustedKeqVal=
	Table[
		adjustedKeqVal[[inhib]], 
	{inhib, Length @ adjustedKeqVal}, {dataSet,  substrateDataRange[[inhib]]}, {Length@dataSet}]//Flatten;

	(*Repeat Assay Conditions for Each Data Point*)
	Do[
		inhibListFull[[inhib, con]]= Table[inhibListFull[[inhib, con]], {rep, Length @ substrateDataRange[[inhib]]}],
	{inhib, Length @ inhibListFull},{con, 7,8}];

	(*Assemble Fitting Data*)

	(*Correct Chemical Activites*)
	assayMet = Map[Transpose[#[[All,2]]]&, inhibListFull[[All,4]]];
	assayCond = Map[Transpose[#]&, inhibListFull[[All,7;;8]]];

	assayMet=
		Table[(* chemical activity = \[Gamma]*[(S^z)] *)
		((*Exp[activityCoefficient[[All,2]]]**)activeIsoSub[[All,2]])/.
			Thread[metsFull->assayMet[[met,pt]]]/.
			parameter["IonicStrength"]->ionicStrength[[met]]/.
			parameter["pH"]->ToExpression[assayCond[[met,pt,1]]],
		{met, Length @ assayMet}, {pt, Length @ assayMet[[met]]}];

	assayMet = Flatten[assayMet,1];
	assayCond = Flatten[assayCond,1];
	
	fileFlagList = Flatten[ Table[inhibListFull[[inhib, -1]], {inhib, Length @ inhibListFull}, {Length @ substrateDataRange[[inhib]]}]];
	vList = Flatten[inhibListFull[[All,-2]],1];(*Target Data*)
	
	assayCond = Table[
					Transpose@ConstantArray[assayCond[[i]],Length @ vList[[i]]],
				{i, Length@assayCond}];

	(*End Correct Chemical Activites*)

	(*this section is identical to kcat simulation - create a common function later*)
	inhibFittingData=
		Table[
			Join[Append[assayMet[[pt]], ConstantArray[eTotal, Length@vList[[pt]]]], assayCond[[pt]]],
		{pt, Length @ assayMet}];

	inhibFittingData=
		Table[
			
			Join[inhibFittingData[[pt]], {ConstantArray[fileFlagList[[pt]], Length@vList[[pt]]], vList[[pt]]}],

		{pt, Length @ inhibFittingData}];

	inhibFittingData = 
		Table[
			Join[{ConstantArray[adjustedKeqVal[[pt,2]], Length@vList[[pt]]]}, inhibFittingData[[pt]]],
		{pt, Length @ inhibFittingData}];
	
	inhibFittingData = Flatten[
							Table[
								MapThread[{##}&, inhibFittingData[[i]]], 
							{i, Length[inhibFittingData]}], 1];

	Return[inhibFittingData];
];


(* ::Subsection:: *)
(*Simulate rate constant ratios  data (e.g.  Keq, dKd, Kd)*)


simulateRateConstRatiosData[ratio_, ratioVal_, KeqVal_, metsFull_, rateConstsSub_, metsSub_, eTotal_, nonKmParamWeight_,
							inputPath_, fileList_, fileListSub_, eqnNameList_, eqnValList_, eqnValListPy_, pHandT_, eqnName_] := 
	Block[{ratioPy, fileName, fileNameSub, eqnList, assayMet, 
			fileListLocal=fileList, fileListSubLocal=fileListSub, 
			eqnNameListLocal=eqnNameList, eqnValListLocal=eqnValList, eqnValListPyLocal=eqnValListPy, 
			fitPt, header, fittingData={}},
			
	(*Transform Equation for Python and Extract the Data from the Database*)

	ratioPy = ToPython[ratio /. rateConstsSub /. metsSub];

	(*Incorporate the Equation Into the Existing Notebook Framework*)
	(*Equation Naming and Export*)
	fileName = FileNameJoin[{inputPath, eqnName <> ".txt"}, OperatingSystem->$OperatingSystem];
	Export[fileName, ratioPy];

	(*Incorporating the Equation for Down Stream Equation Handling*)
	fileListLocal = DeleteDuplicates @ Append[fileListLocal, fileName];
	fileNameSub  = fileName -> ratio;
	fileListSubLocal = DeleteDuplicates @ Append[fileListSubLocal, fileNameSub];
	eqnNameListLocal = DeleteDuplicates @ Append[eqnNameListLocal, eqnName];
	eqnValListLocal = DeleteDuplicates @ Append[eqnValListLocal, ratio];
	eqnValListPyLocal = DeleteDuplicates @ Append[eqnValListPyLocal, ratioPy];

	(*Data Handling for Fitting*)

	assayMet = 0 & /@ metsFull; (*Set All Mets to Zero*)
	AppendTo[assayMet, eTotal]; (*Enzyme Total*)
	fitPt = Join[assayMet, pHandT];(*pH and Temperature - dirty trick, assayCond comes from Km data sim*)
	fitPt = Join[fitPt, {"\""<>fileName<>"\"", ratioVal}];(*File Name and Target Value*)
	fitPt = Join[{KeqVal}, fitPt];(*Keq Value*)(*Append Data*)

	If[! MemberQ[fittingData, fitPt],(*True:  Data Is Not Already Appended*)
		Do[
			AppendTo[fittingData, fitPt], 
		{nonKmParamWeight}](*Data Weight*)];

	
	Return[{fittingData, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal}];
];


(* ::Subsection:: *)
(*Parameter scan function*)


simulateParameterScanData[inputPath_, dataType_, dataList_, dataEntry_, newValuesList_, remainingFittingDataset_, dataFileName_, metsSub_, simulateDataFunctionArguments_]:= 
	Block[{newValuesListLocal=newValuesList, dataListLocal=dataList,simulateDataFunctionArgumentsLocal=simulateDataFunctionArguments, header, 
		   scannedfittingData, fittingData, dataPath, vList, dataPathList, labelList={}},
	
	newValuesListLocal = Map[ToString[AccountingForm[#]]&, newValuesListLocal];
	header=Join[Map[ToString, metsSub[[All,1]]],{"FileFlag", "Target_Data"}];
	
	dataPathList = Table[
			scannedfittingData = Which[StringMatchQ[dataType, {"Km"}],
									dataListLocal[[dataEntry,2]] = ToExpression[val];
									simulateDataFunctionArgumentsLocal[[5]] = dataListLocal;
									Apply[simulateKmData, simulateDataFunctionArgumentsLocal],
							
									StringMatchQ[dataType, {"s05"}],
									dataListLocal[[dataEntry,2]] = ToExpression[val];
									simulateDataFunctionArgumentsLocal[[5]] = dataListLocal;
									Apply[simulateS05Data, simulateDataFunctionArgumentsLocal],
							
									StringMatchQ[dataType, {"kcat"}],
									dataListLocal[[dataEntry,2]] = ToExpression[val];
									simulateDataFunctionArgumentsLocal[[5]] = dataListLocal;
									Apply[simulateKcatData, simulateDataFunctionArgumentsLocal],
							
									StringMatchQ[dataType, {"inhib"}],
									dataListLocal[[dataEntry,3]] = ToExpression[val];
									simulateDataFunctionArgumentsLocal[[5]] = dataListLocal;
									Apply[simulateInhibData, simulateDataFunctionArgumentsLocal],
							
									StringMatchQ[dataType, {"ratio"}],
									simulateDataFunctionArgumentsLocal[[2]] = ToExpression[val];
									Apply[simulateRateConstRatiosData, simulateDataFunctionArgumentsLocal][[1]]
									
							];

		(* assemble data and export*)
		fittingData= Flatten[{{scannedfittingData}, remainingFittingDataset}, 2];
		dataPath = FileNameJoin[{inputPath, dataFileName <> "_" <> dataType <> "_" <> ToString[dataEntry] <> "_" <> ToString[val] <> ".dat"}, OperatingSystem->$OperatingSystem];
		AppendTo[labelList,  "_" <> dataType <> "_" <> ToString[dataEntry] <> "_" <> ToString[val]];
		vList = Join[{header},fittingData];
		Export[dataPath, vList, "Table"];
		dataPath,
	
	{val, newValuesListLocal}];
	
	Return[{dataPathList, labelList}];		
];


exportData[fittingData_,inputPath_, dataFileName_, metsSub_] := Block[{header, fittingDataLocal, dataPath, vList},
	
	header=Join[Map[ToString, metsSub[[All,1]]],{"FileFlag", "Target_Data"}];
	fittingDataLocal = Flatten[fittingData, 1];
	dataPath =FileNameJoin[{inputPath,dataFileName <>".dat"}, OperatingSystem->$OperatingSystem];
	
	vList=Join[{header},fittingDataLocal];
	Export[dataPath,vList,"Table"];

	Return[{fittingDataLocal, dataPath}];
];


(* ::Subsection:: *)
(*Simulate all data automatically*)


simulateData[enzymeModel_,dataFileName_, haldaneRatiosList_, KmList_, s05List_, kcatList_, inhibList_, activationList_, otherParmsList_, rxn_, metsFull_,  
			metSatForSub_, metSatRevSub_,   bufferInfo_, ionCharge_, inputPath_,  fileList_, fileListSub_, 
			eqnNameList_,eqnValList_, eqnValListPy_, eqnNameList_, rateConstsSub_, 
			metsSub_, KeqEquilibrator_, KeqName_, allCatalyticReactions_, unifiedRateConstList_, customRatiosList_:{}]:=

	Block[{kmFittingData, s05FittingData, kcatFittingData, inhibFittingData, activationData,  KeqFittingData, KdFittingData, 
			L0FittingData, inhibRatioFittingData, customRatioFittingData, activationRatioFittingData, haldane, haldaneRatio,
			logStepSize, minPsDataVal, maxPsDataVal,nonKmParamWeight, eTotal, assumedSaturatingConc, inVivoPH, inVivoIS, 
			effectiveIonDiameter, activityCoefficient, activeIsoSub, pHandT, paramType,ratio,  val, inhibitor, activator, 
			fileListLocal=fileList, fileListSubLocal=fileListSub, eqnNameListLocal=eqnNameList, eqnValListLocal=eqnValList,
			eqnValListPyLocal=eqnValListPy, affectedRxnList, affectedRxnProductsList, reactionOverlap, count, allFittingData={},
			dataPath},

	(* define key parameters *)
	logStepSize=0.2;
	(*nonKmParamWeight=3;*)
	(*Weighting factor for non-Km data points. You can be specify this manually*)
	{minPsDataVal, maxPsDataVal}= getMinMaxPsDataVal[1];
	nonKmParamWeight=Length[Table[1,{i,minPsDataVal, maxPsDataVal,logStepSize}]];
	eTotal=1;(*Enzyme Total, Should Be 1 for Fitting*)
	assumedSaturatingConc=0.01 ;(*in Molarity*)

	(* chemical activity correction parameters *)
	inVivoPH=7.5;(*Assumed in vivo pH*)
	inVivoIS=0.25;(*Assumed in vivo Ionic Strength, in Molarity*)
	effectiveIonDiameter=3;(*Used in Debye-Huckel equation, in Angstroms*)
	
	(* initialization of chemical activity correction. these values represent no correction (ie chemical activity is just the metabolite concentration *)
	activeIsoSub=Thread[metsFull->metsFull];(*[(S^z)] = [S] *)
	activityCoefficient=Thread[metsFull->1];(* \[Gamma] = 1 *)

	pHandT= {7, 25};

	Do[
		(* simulate Keq data 
		haldane=haldaneRelation[KeqName,allCatalyticReactions]/.unifiedRateConstList;
		haldaneRatio=haldane[[2]];*)
		{KeqFittingData, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal} = 
				simulateRateConstRatiosData[haldaneRatiosList[[haldaneI,1]], haldaneRatiosList[[haldaneI,2]], KeqEquilibrator, metsFull, rateConstsSub, metsSub, eTotal, nonKmParamWeight, inputPath, 
										fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal, pHandT, "haldaneRatio_"<>ToString[haldaneI]];
		
		AppendTo[allFittingData,KeqFittingData];,
	{haldaneI, 1, Length@haldaneRatiosList}];

	If[ !SameQ[KmList, {}],
		kmFittingData= simulateKmData[rxn, metsFull,  metSatForSub, metSatRevSub, KmList, otherParmsList, assumedSaturatingConc, eTotal,
									logStepSize,activeIsoSub, bufferInfo, ionCharge, inputPath,  fileListLocal, KeqEquilibrator];

		AppendTo[allFittingData,kmFittingData];
	];

	If[!SameQ[s05List,{}],
		s05FittingData = simulateS05Data[rxn, metsFull, metSatForSub, metSatRevSub, s05List, otherParmsList, assumedSaturatingConc, eTotal,
										logStepSize, activeIsoSub, bufferInfo, ionCharge, inputPath,  fileListLocal, KeqEquilibrator];

		AppendTo[allFittingData,s05FittingData];
	];

	If[ !SameQ[kcatList, {}],
		kcatFittingData=simulateKcatData[rxn, metsFull,  metSatForSub, metSatRevSub, kcatList, otherParmsList, assumedSaturatingConc, eTotal,
										logStepSize, nonKmParamWeight, activeIsoSub, bufferInfo, ionCharge, inputPath,  fileListLocal, KeqEquilibrator];

		AppendTo[allFittingData,kcatFittingData];
	];

	If[ !SameQ[inhibList, {}],

		logStepSize=0.5;
		inhibFittingData=simulateInhibData[rxn, metsFull, metSatForSub, metSatRevSub,  inhibList,KmList, assumedSaturatingConc, eTotal, logStepSize, 
											activeIsoSub, bufferInfo, ionCharge, inputPath, fileListLocal, KeqEquilibrator];

		AppendTo[allFittingData,inhibFittingData];

		Do[

			inhibitor=m[inhibEntry[[2]],"c"];
			affectedRxnList=Select[enzymeModel["Reactions"],MemberQ[getSubstrates[#], inhibitor]&];
			affectedRxnProductsList =Map[getProducts[#]&,affectedRxnList];
			reactionOverlap = Table[
						Map[MemberQ[Flatten@{getSubstrates[#], getProducts[#]},affectedRxnProducts[[1]]]&,enzymeModel["Reactions"]],
					{affectedRxnProducts, affectedRxnProductsList}];

			If[AnyTrue [Map[Count[#, True]&,reactionOverlap], #<= 1&],
				ratio = getRatio[enzymeModel, inhibitor];
				val=inhibEntry[[3]];

				{inhibRatioFittingData, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal} = 
						simulateRateConstRatiosData[ratio,val, KeqEquilibrator, metsFull, rateConstsSub, metsSub, eTotal, nonKmParamWeight, 
													inputPath, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal, pHandT, 
													eqnName= inhibEntry[[2]]<>"_inhibRatio"];
	
				AppendTo[allFittingData,inhibRatioFittingData];

			];,
		{inhibEntry, inhibList}];
	];

	If[ !SameQ[activationList, {}],

		Do[
			activator=m[activationEntry[[2]],"c"];
			ratio = getRatio[enzymeModel, activator];
			val=activationEntry[[3]];

			{activationRatioFittingData, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal} = 
					simulateRateConstRatiosData[ratio,val, KeqEquilibrator, metsFull, rateConstsSub, metsSub, eTotal, nonKmParamWeight, inputPath, fileListLocal, 
												fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal, pHandT, eqnName= activationEntry[[2]]<>"_inhibRatio"];
												
			AppendTo[allFittingData,activationRatioFittingData];,

		{activationEntry, activationList}];

	];

	If[ !SameQ[otherParmsList, {}],
		Do[
			paramType = paramEntry[[1]];

			Which[
				StringStartsQ[paramType, "Kd"],
				ratio= getRatio[enzymeModel, m[paramEntry[[2]],"c"]];
				val = paramEntry[[3]];

				{KdFittingData, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal} = 
					simulateRateConstRatiosData[ratio,val, KeqEquilibrator, metsFull, rateConstsSub, metsSub, eTotal, nonKmParamWeight, inputPath,
												 fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal, pHandT, "KdRatio"];

				AppendTo[allFittingData,KdFittingData];,


				StringStartsQ[paramType, "L0"],
				ratio = getAllostericTransitionRatio[enzymeModel, nonCatalyticReactions];
				val =getOtherParamsValue[paramType, otherParmsList];

				{L0FittingData, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal} = 
					simulateRateConstRatiosData[ratio,val, KeqEquilibrator, metsFull, rateConstsSub, metsSub, eTotal, nonKmParamWeight, 
												inputPath, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal, 
												pHandT, "L0Ratio"];

				AppendTo[allFittingData,L0FittingData];
			 ];,

		{paramEntry, otherParmsList}];
	];

	If[!SameQ[customRatiosList, {}],
		count =1;
		Do[
			ratio= customRatio[[1]];
			val = customRatio[[2]];

			{customRatioFittingData,fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal} = 
				simulateRateConstRatiosData[ratio,val, KeqEquilibrator, metsFull, rateConstsSub, metsSub, eTotal, nonKmParamWeight, 
											inputPath, fileListLocal, fileListSubLocal, eqnNameListLocal, eqnValListLocal, eqnValListPyLocal, 
											pHandT, "customRatio_"<>ToString[count]];

			AppendTo[allFittingData,customRatioFittingData];
			count = count +1,

		{customRatio, customRatiosList} ];
	];


	{allFittingData, dataPath} = exportData[allFittingData,inputPath,dataFileName, metsSub];

	Return[{allFittingData, dataPath}];
];



(* ::Subsection:: *)
(*Simulate all data with uncertainty automatically*)


simulateDataWithUncertainty[nSamples_,enzymeModel_,dataFileBaseName_, haldaneRatiosList_, KmList_, s05List_, kcatList_, inhibList_, activationList_, othersList_, 
							rxn_, metsFull_,  metSatForSub_, metSatRevSub_, otherParmsList_,  bufferInfo_, ionCharge_, inputPath_,  fileList_, 
							fileListSub_, eqnNameList_,eqnValList_, eqnValListPy_, eqnNameList_, rateConstsSub_, 
							metsSub_,KeqEquilibrator_, KeqName_,allCatalyticReactions_, unifiedRateConstList_, customRatiosList_:{}]:=
	Block[{haldaneRatiosListLocal=haldaneRatiosList,KmListLocal=KmList, s05ListLocal=s05List, kcatListLocal= kcatList, inhibListLocal=inhibList, activationListLocal=activationList, 
			otherParmsListLocal=otherParmsList, customRatiosListLocal=customRatiosList,KeqEquilibratorLocal=KeqEquilibrator, uncertainty, 
			newValue, dataFileName, allFittingData, dataPath, allFittingDataList={}, dataPathList={}},
	
	Do[
	
		If[ !SameQ[haldaneRatiosList, {}],
			Do[
				uncertainty = Abs[haldaneRatiosList[[haldaneI]][[3]][[2]]- haldaneRatiosList[[haldaneI]][[3]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ haldaneRatiosList[[haldaneI]][[2]], uncertainty]];
				haldaneRatiosListLocal[[haldaneI]][[2]] = newValue;,

		{haldaneI, 1, Length@ haldaneRatiosList}];
		];
				
		If[ !SameQ[KmList, {}],
			Do[
				uncertainty = Abs[KmList[[kmEntryI]][[3]][[2]]- KmList[[kmEntryI]][[3]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ KmList[[kmEntryI]][[2]], uncertainty]];
				KmListLocal[[kmEntryI]][[2]] = newValue;,

		{kmEntryI, 1, Length@ KmList}];
		];


		If[!SameQ[s05List,{}],
			Do[
				uncertainty = Abs[s05List[[s05EntryI]][[3]][[2]]- s05List[[s05EntryI]][[3]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ s05List[[s05EntryI]][[2]], uncertainty]];
				s05ListLocal[[s05EntryI]][[2]] = newValue;,

			{s05EntryI, 1, Length@ s05List}];
		];

		If[ !SameQ[kcatList, {}],
			Do[
				uncertainty = Abs[kcatList[[kcatEntryI]][[3]][[2]]- kcatList[[kcatEntryI]][[3]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ kcatList[[kcatEntryI]][[2]], uncertainty]];
				kcatListLocal[[kcatEntryI]][[2]] = newValue;,

			{kcatEntryI, 1, Length@ kcatList}];
		];

		If[ !SameQ[inhibList, {}],
			Do[
				uncertainty = Abs[inhibList[[inhibEntryI]][[4]][[2]]- inhibList[[inhibEntryI]][[4]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ inhibList[[inhibEntryI]][[3]], uncertainty]];
				inhibListLocal[[inhibEntryI]][[3]] = newValue;,

				{inhibEntryI, 1, Length@ inhibList}];
		];

		If[ !SameQ[activationList, {}],
			Do[
				uncertainty = Abs[activationList[[activationEntryI]][[4]][[2]]- activationList[[activationEntryI]][[4]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ activationList[[activationEntryI]][[3]], uncertainty]];
				activationListLocal[[activationEntryI]][[3]] = newValue;,

			{activationEntryI, 1, Length@ activationList}];

		];

		If[ !SameQ[otherParmsList, {}],
			Do[
				uncertainty = Abs[otherParmsList[[otherEntryI]][[4]][[2]]- otherParmsList[[otherEntryI]][[4]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ otherParmsList[[otherEntryI]][[3]], uncertainty]];
				otherParmsListLocal[[otherEntryI]][[3]] = newValue;,
	
			{otherEntryI, 1, Length@ otherParmsList}];
		];

		If[!SameQ[customRatiosList, {}],
			Do[
				uncertainty = Abs[customRatiosList[[customRatioEntryI]][[3]][[2]]- customRatiosList[[customRatioEntryI]][[3]][[1]]]/2.;
				newValue = RandomVariate[NormalDistribution[ customRatiosList[[customRatioEntryI]][[2]], uncertainty]];
				customRatiosListLocal[[customRatioEntryI]][[2]] = newValue;,

			{customRatioEntryI, 1, Length@ customRatiosList}];
		];

		dataFileName = dataFileBaseName <> "_" <>ToString[sampleI];
	
		{allFittingData, dataPath} = simulateData[enzymeModel,dataFileName,haldaneRatiosListLocal,KmListLocal, s05ListLocal, kcatListLocal, inhibListLocal, 
													activationListLocal, otherParmsListLocal, rxn, metsFull,  metSatForSub, metSatRevSub, 
													bufferInfo, ionCharge, inputPath,  fileList,fileListSub, eqnNameList,eqnValList, eqnValListPy, 
													eqnNameList, rateConstsSub, metsSub,KeqEquilibratorLocal, KeqName,allCatalyticReactions, 
													unifiedRateConstList, customRatiosListLocal];

		AppendTo[allFittingDataList, allFittingData];
		AppendTo[dataPathList, dataPath];,

	{sampleI, 1, nSamples}];

	Return[{allFittingDataList, dataPathList}];
];



(* ::Subsection:: *)
(*End*)


End[];
