# Nodrix

تطبيق إدارة شبكة وساس تجريبي.

## إصدار v1.0.2

- تحسين زر التحديثات: يحاول فتح رابط تحميل APK مباشرة في المتصفح.
- إضافة زر احتياطي لنسخ رابط التحديث.
- إضافة صفحة **تفاصيل المشترك**.
- تحسينات عربية بسيطة على الواجهة.

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

## Endpoint التحديثات

```txt
GET /api/app-version
```

## متغيرات التحديثات في Railway

```txt
APP_LATEST_VERSION=1.0.2
APP_APK_URL=https://github.com/samer-am/nodrix-app/releases/download/v1.0.2/nodrix-v1.0.2.apk
APP_UPDATE_NOTES=تحسين تحميل التحديثات وإضافة صفحة تفاصيل المشترك
PUBLIC_BASE_URL=https://nodrix-app-production.up.railway.app
```

## بناء APK

```cmd
cd /d "E:\nodrix-app\mobile_flutter"
flutter clean
flutter pub get
flutter build apk --debug
```

المسار:

```txt
E:\nodrix-app\mobile_flutter\build\app\outputs\flutter-apk\app-debug.apk
```

## رفع إصدار جديد

```cmd
cd /d "E:\nodrix-app"
git add .
git commit -m "Release v1.0.2"
git push
```

ثم ارفع APK على GitHub Releases باسم `v1.0.2`، وبعدها عدّل `APP_LATEST_VERSION` و `APP_APK_URL` في Railway.


## v1.0.3
- تحسين UI/UX عربي.
- إصلاح رقم النسخة داخل التطبيق.
- إضافة/تعديل مشتركين على mock backend.
- تسجيل دفعة مبدئي.
