(* Created with the Wolfram Language for Students - Personal Use Only : www.wolfram.com *)
(2*metabolite["f6p", "c"]^2*metabolite["pi", "c"]^2*parameter["FBP2_total"]*
  rateconst["FBP21", False]*rateconst["FBP22", False]*
  rateconst["FBP23", False]*rateconst["FBP24", False]*
  rateconst["FBP25", False]*rateconst["FBP26", False]*
  rateconst["FBP27", False])/
 (metabolite["f6p", "c"]^2*(rateconst["FBP21", False]*
     rateconst["FBP22", True]*rateconst["FBP23", False]*
     rateconst["FBP25", False] + metabolite["pi", "c"]*
     rateconst["FBP21", False]*rateconst["FBP23", False]*
     (rateconst["FBP22", False] + rateconst["FBP24", False])*
     rateconst["FBP25", False] + metabolite["pi", "c"]^2*
     rateconst["FBP22", False]*rateconst["FBP24", False]*
     (rateconst["FBP23", False]*rateconst["FBP25", False] + 
      rateconst["FBP21", False]*(rateconst["FBP23", False] + 
        rateconst["FBP25", False] + rateconst["FBP25", True])))*
   rateconst["FBP26", False]*rateconst["FBP27", False] + 
  rateconst["FBP21", False]*(metabolite["pi", "c"]^2*
     rateconst["FBP22", False]*rateconst["FBP24", False] + 
    metabolite["pi", "c"]*rateconst["FBP22", False]*
     rateconst["FBP24", True] + rateconst["FBP22", True]*
     rateconst["FBP24", True])*rateconst["FBP26", True]*
   (rateconst["FBP25", True]*rateconst["FBP27", True] + 
    rateconst["FBP23", False]*(rateconst["FBP25", False] + 
      rateconst["FBP27", True])) + metabolite["f6p", "c"]*
   rateconst["FBP21", False]*(metabolite["pi", "c"]*rateconst["FBP22", False]*
     rateconst["FBP23", False]*rateconst["FBP24", True]*
     rateconst["FBP25", False]*rateconst["FBP27", False] + 
    rateconst["FBP22", True]*rateconst["FBP23", False]*
     rateconst["FBP24", True]*rateconst["FBP25", False]*
     rateconst["FBP27", False] + metabolite["pi", "c"]^2*
     rateconst["FBP22", False]*rateconst["FBP24", False]*
     (rateconst["FBP25", True]*rateconst["FBP26", False]*
       rateconst["FBP27", True] + rateconst["FBP23", False]*
       (rateconst["FBP25", False]*(rateconst["FBP26", False] + 
          rateconst["FBP27", False]) + rateconst["FBP26", False]*
         rateconst["FBP27", True]))))