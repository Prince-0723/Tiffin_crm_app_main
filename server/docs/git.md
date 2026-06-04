git checkout main
git pull

git checkout -b " ”
git add .
git status
git commit -m " ”
git push -u origin CurrentBranchName
git push

<!-- after pushing my code to my current code and brach is completed -->

git checkout main
git pull origin main
git merge feature/foundation-setup
git push origin main

<!-- locally -->
git branch -d feature/foundation-setup

<!-- from remote branch  -->
git push origin --delete feature/foundation-setup

<!-- if not merge -->

git checkout backendSetup
git pull origin backendSetup
git checkout -b feature-newThing

<!-- if merge -->

git checkout main
git pull origin main
git checkout -b eature-newFeature

feature/foundation-setup
feature/auth-otp-jwt
feature/customer-crud
feature/plan-crud
feature/subscription-crud
feature/delivery-system
feature/socket-delivery
feature/payment-system
feature/invoice-webhook
feature/notifications-fcm
feature/reports-analytics
feature/api-hardening
