Don't forget to read and store CLAUDE.md in the main AppWare folder in memory before you start.

Introduction
-------------
Scan the entire folder, there's 4 folders: AppWare Auth, Hungry, Roomies, Jukebox. Hungry, Roomies and Jukebox are apps all under AppWare. AppWare Auth is the feature I'm trying to set up on all my apps, a "Sign in with AppWare" feature. I want to build an AppWare ecosystem, where user data can travel from one app to another, and everything is synced.

AppWare Auth
------------
The user should be able to create a single sign in account, an AppWare account. The auth website is hosted at authappware.netlify.app. There also a Supabase project set up for it, which you will find in every .env file in the projects. The AppWare account will take sign in with google, sign in with apple, and just regular email and password set up. The user will then be able to sign into the app they're using with AppWare, and their AppWare data from other apps will sync up. For example, they use Hungry and Roomies, the shared grocery lists, spending, etc. can all be synced. Friends lists can be synced. Many more ideas. The point is, they should all share data, and AppWare Auth can act as a single log in for all of them. I want to build an AppWare ecosystem with seamless integration. Each app will still collect any data about the user during the onboarding process that is specific to the app like it already does.



What is already done:
----------------------
Each .env file has been updated with the AppWare supabase project. One of them even has the netlify link for auth already. Sign up with Google has been set up on Supabase. Multiple SQL Queries have been run, and you'll find those .sql files in the projects. The problem I'm running into is all those queries were set up independently, so they're kind of clashing with each other and I'm getting errors


What your job is:
-----------------

Go through all the folders in this folder, and understand the app. Use Claude's memory files, Notes files, and Feature tracking files to understand what is going on (not limited to just these files). Then, build robust database architecture that I can put into Supabase to set this up. Consider everything from all the apps, and build it so that it works seamlessly through everything. The output should be one final SQL file with a complete, encompassing, robust database design, so I can copy that query and directly paste it into Supabase. If the current set up on supabase needs to be wiped, make provisions for that. The only thing you should output is the SQL file, and clear instructions on what I need to do. 