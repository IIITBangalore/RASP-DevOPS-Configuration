1. Change .env in `RASPutin/rasp-fe/Drag-Drop(RFE)` to reflect where the backend is hosted before building the docker image

1. Update CORS configuration in `rasp-fe/Drag-Drop(RBE)/server.ts` to point to your domain

1. Update session store to use some persistent store - can't store session information and so have to use `req.cookies?.jwt` as fallback to `req.session?.accessToken` in `verifyJWT` method