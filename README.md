# Nodrix

تطبيق إدارة شبكة وساس تجريبي.

## آخر تحديث

- تعريب كامل للواجهة.
- إضافة صفحة **التحديثات** داخل التطبيق.
- إضافة Endpoint في الـ Backend:

```txt
GET /api/app-version
```

## تشغيل Backend محليًا

```cmd
cd backend
npm install
npm start
```

## فحص Railway

```txt
https://nodrix-app-production.up.railway.app/health
```

## متغيرات التحديثات في Railway

يمكنك تغيير معلومات آخر إصدار من Railway بدون تعديل التطبيق:

```txt
APP_LATEST_VERSION=0.2.1
APP_APK_URL=https://your-download-link/app-debug.apk
APP_UPDATE_NOTES=نص ملاحظات التحديث
PUBLIC_BASE_URL=https://nodrix-app-production.up.railway.app
```

إذا لم تضع `APP_APK_URL`، سيحاول التطبيق استخدام:

```txt
/downloads/nodrix-latest.apk
```

## بناء APK

```cmd
cd mobile_flutter
flutter create .
flutter pub get
flutter build apk --debug
```

المسار:

```txt
mobile_flutter\build\app\outputs\flutter-apk\app-debug.apk
```
