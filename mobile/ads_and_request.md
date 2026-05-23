From the Creator's Side                                                                                                                                        
                                                                                                                                                                 
  Posting a Request (free, quick)                                                                                                                                
                                                                                                                                                                 
  The user taps Post a Request and fills in the form — title, description, event type, location, and optional budget. When they submit, the app calls:           
                                                                                                                                                                 
  ▎ POST /ads/requests                                                                                                                                           
                                                            
  The request lands in admin review with status pending_review. Once an admin approves it:                                                                       
                                                            
  ▎ PATCH /ads/admin/requests/{id}/approve                                                                                                                       
                                                            
  It becomes open and live on the board for others to see.                                                                                                       
   
  ---                                                                                                                                                            
  Creating an Ad Campaign (paid, more reach)                
                                            
  Step 1 — Create the campaign shell
                                                                                                                                                                 
  User fills in name, objective, budget, currency, and dates. App calls:                                                                                         
                                                                                                                                                                 
  ▎ POST /ads/campaigns                                                                                                                                          
                                                            
  Returns a campaign_id. Status is draft.                                                                                                                        
   
  Step 2 — Add targeting (Ad Set)                                                                                                                                
                                                            
  User picks placement, audience, event types, location, and bid amount. App calls:                                                                              
   
  ▎ POST /ads/campaigns/{campaign_id}/adsets                                                                                                                     
                                                            
  Step 3 — Add the creative (the Ad)                                                                                                                             
                                                            
  User writes headline, body, CTA text and link. App calls:                                                                                                      
                                                            
  ▎ POST /ads/adsets/{adset_id}/ads                                                                                                                              
   
  If they upload an image or video:                                                                                                                              
                                                            
  ▎ POST /ads/ads/{ad_id}/media                                                                                                                                  
   
  Step 4 — Pay to launch                                                                                                                                         
                                                            
  User taps Pay. App calls:                                                                                                                                      
   
  ▎ POST /ads/campaigns/{campaign_id}/pay                                                                                                                        
                                                            
  Returns a Paystack authorization_url. App opens it in a WebView. User completes payment. Paystack automatically hits the backend webhook:                      
   
  ▎ POST /webhooks/paystack                                                                                                                                      
                                                            
  Campaign moves to pending_review.

  Step 5 — Admin approves                                                                                                                                        
   
  ▎ PATCH /ads/admin/campaigns/{id}/approve                                                                                                                      
                                                            
  Campaign becomes active. Recommender boost is published. Ad starts serving.                                                                                    
   
  ---                                                                                                                                                            
  Promoting a Request to a Campaign                         

  User taps Promote on their own request. App calls:

  ▎ POST /ads/requests/{id}/promote

  A draft campaign is created pre-filled from the request. App takes the user straight to the Pay step:                                                          
  
  ▎ POST /ads/campaigns/{campaign_id}/pay                                                                                                                        
                                                            
  Same Paystack flow. Once approved, the request stays on the board AND the ad runs in the feed simultaneously.                                                  
  
  ---                                                                                                                                                            
  When Budget Runs Out                                      
                      
  Celery checks every 5 minutes automatically — no API call needed from the app. When it detects the campaign is spent, it pauses it. The user gets notified and
  taps Top Up. App calls:                                                                                                                                        
   
  ▎ POST /ads/campaigns/{campaign_id}/topup?amount=200                                                                                                           
                                                            
  Same Paystack WebView. After payment the campaign resumes active automatically.                                                                                
   
  ---                                                                                                                                                            
  Managing Own Requests                                     
                                                                                                                                                                 
  User opens their own requests tab. App calls:
                                                                                                                                                                 
  ▎ GET /ads/requests/mine                                  

  When they want to close or mark one as filled:                                                                                                                 
   
  ▎ POST /ads/requests/{id}/close?status=filled                                                                                                                  
                                                            
  or                                                                                                                                                             
                                                            
  ▎ POST /ads/requests/{id}/close?status=closed

  ---
  From the Viewer's Side
                        
  Seeing an Ad in the Feed
                                                                                                                                                                 
  Every time a screen loads, the app silently calls:
                                                                                                                                                                 
  ▎ GET /ads/serve?placement=event_feed&context_event_type=wedding&context_location=Accra                                                                        
   
  The backend returns the best matching active ad or null. If an ad comes back the app renders it in the feed. The moment it becomes visible on screen:          
                                                            
  ▎ POST /ads/track/impression                                                                                                                                   
                                                            
  When the user taps the CTA button:                                                                                                                             
   
  ▎ POST /ads/track/click                                                                                                                                        
                                                            
  If that interaction leads to a photo purchase:                                                                                                                 
   
  ▎ POST /ads/track/conversion                                                                                                                                   
                                                            
  When they tap the Message button on the ad — no API call to the ads service. The app just opens the existing chat screen using the advertiser_id that came in  
  the ad response.
                                                                                                                                                                 
  Placement values to pass per screen:                                                                                                                           
  
  ┌──────────────────────┬──────────────────┐                                                                                                                    
  │        Screen        │ placement value  │               
  ├──────────────────────┼──────────────────┤
  │ Event feed           │ event_feed       │
  ├──────────────────────┼──────────────────┤
  │ Search results       │ search_results   │
  ├──────────────────────┼──────────────────┤
  │ After face match     │ post_recognition │
  ├──────────────────────┼──────────────────┤                                                                                                                    
  │ Photographer profile │ profile_page     │
  └──────────────────────┴──────────────────┘                                                                                                                    
                                                            
  ---                                                                                                                                                            
  Browsing the Request Board                                

  User opens the Request Board. App calls:

  ▎ GET /ads/requests

  Filtered results come back based on the viewer's role — photographers see client requests, clients see photographer requests. If they filter by event type or  
  location:
                                                                                                                                                                 
  ▎ GET /ads/requests?event_type=wedding&location=Accra                                                                                                          
   
  User taps a request card to see the full detail:                                                                                                               
                                                            
  ▎ GET /ads/requests/{id}

  They tap Message — again, straight into the existing chat with requester_id. No ads service call needed.                                                       
   
  ---                                                                                                                                                            
  The Complete Loop with Endpoints                          

  POST /ads/requests                    ← creator posts
        or                                                                                                                                                       
  POST /ads/campaigns                   ← creator sets up campaign
  POST /ads/campaigns/{id}/adsets                                                                                                                                
  POST /ads/adsets/{id}/ads                                                                                                                                      
  POST /ads/campaigns/{id}/pay
  POST /webhooks/paystack               ← Paystack confirms payment                                                                                              
  PATCH /ads/admin/campaigns/{id}/approve  ← admin approves                                                                                                      
            ↓
  GET  /ads/serve?placement=X           ← viewer's screen loads                                                                                                  
  POST /ads/track/impression            ← viewer sees it                                                                                                         
  POST /ads/track/click                 ← viewer taps it                                                                                                         
            ↓                                                                                                                                                    
            chat opens using advertiser_id (existing chat service)                                                                                               
            ↓                                                                                                                                                    
            they connect, deal is made
            ↓                                                                                                                                                    
  POST /ads/requests/{id}/close         ← creator marks it done
 