/*
===================================================================
📜 ملف JavaScript لتحليل صفحات فيسبوك - "Fb Explorer Fyras"
===================================================================
📅 الإصدار: 1.0 (المُحسّن - مع دعم الأرقام العربية والتحسينات)
===================================================================

🎯 المميزات المحسّنة:
1. دعم كامل للأرقام العربية والإنجليزية
2. اكتشاف محسّن للمنشورات
3. أداء أفضل مع requestAnimationFrame
4. معالجة أخطاء محسنة
==================================================================*/

// ===================================================================
// 🛡️ منع الحقن المتكرر
// ===================================================================
if (window.flutterInjected) {
    console.log('✅ كود Fb Explorer Fyras محقون مسبقًا');
    return;
}
window.flutterInjected = true;
console.log('🚀 بدء حقن كود Fb Explorer Fyras');

// ===================================================================
// 🧹 وظائف المساعدة (المُحسّنة)
// ===================================================================

/**
 * 🔤 تنظيف النص
 */
function cleanText(text) {
    return text ? text.replace(/\s+/g, ' ').trim() : '';
}

/**
 * 📞 استخراج رقم الهاتف (بدعم كامل للعربية والإنجليزية)
 * 
 * 📱 يدعم التنسيقات:
 * - الإنجليزية: 092810009, 0501234567, +966501234567
 * - العربية: ٠٩٢٨١٠٠٠٩, ٠٥٠١٢٣٤٥٦٧
 * - مختلطة: ٠928١٠٠٠9
 */
function extractPhone(text) {
    if (!text) return null;
    
    // تحويل الأرقام العربية والفارسية إلى إنجليزية
    const normalizedText = text
        .replace(/[٠١٢٣٤٥٦٧٨٩]/g, d => '٠١٢٣٤٥٦٧٨٩'.indexOf(d))
        .replace(/[۰۱۲۳۴۵۶۷۸۹]/g, d => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d));
    
    // أنماط متعددة للهواتف (تغطي معظم الصيغ العربية)
    const phonePatterns = [
        /0?5[0-9]{8}/,                    // 0501234567 أو 501234567
        /0?9[0-9]{8}/,                    // 092810009 أو 92810009
        /(?:\+?966|00966)?5[0-9]{8}/,     // مع مفتاح الدولة
        /0?5\d\s?\d{3}\s?\d{4}/,          // مع مسافات: 05 0 123 4567
        /0?5\d-\d{3}-\d{4}/               // مع فواصل: 05-0-123-4567
    ];
    
    for (const pattern of phonePatterns) {
        const match = normalizedText.match(pattern);
        if (match) {
            // تنظيف الرقم (إزالة كل ما ليس رقمًا)
            const cleanNumber = match[0].replace(/[^\d]/g, '');
            
            // التحقق من الطول الصحيح (9 أو 10 أرقام للهواتف السعودية)
            if (cleanNumber.length >= 9 && cleanNumber.length <= 10) {
                console.log('📞 تم اكتشاف رقم هاتف:', cleanNumber);
                return cleanNumber;
            }
        }
    }
    
    return null;
}

/**
 * 🔍 اكتشاف تسجيل الدخول الناجح
 */
function detectLoginSuccess() {
    const indicators = [
        document.querySelector('[data-pagelet="LeftNavigation"]'),
        document.querySelector('[aria-label="حسابك"]'),
        document.querySelector('a[href*="facebook.com/me"]'),
        !document.querySelector('input[name="email"]')
    ];
    
    const isLoggedIn = indicators.some(indicator => indicator !== null && indicator !== false);
    
    if (isLoggedIn && window.FlutterApp) {
        window.FlutterApp.postMessage('LOGIN_SUCCESS');
    }
    
    return isLoggedIn;
}

// ===================================================================
// 🕵️‍♂️ اكتشاف المنشورات (المُحسّن)
// ===================================================================

/**
 * 🔎 البحث عن المنشورات
 */
function findPosts(root) {
    let posts = [];
    
    // المؤشرات الذكية (مرتبة حسب الموثوقية)
    const selectors = [
        '[role="article"]',
        'div[data-testid="post"]',
        '.userContentWrapper',
        'div[aria-posinset]',
        'div[data-ad-preview="message"]',
        'section',
        'article'
    ];
    
    for (let selector of selectors) {
        try {
            const elements = root.querySelectorAll(selector);
            if (elements.length > 3) { // تأكيد أننا وجدنا منشورات حقيقية
                posts = Array.from(elements);
                break;
            }
        } catch (error) {
            continue;
        }
    }
    
    // التحليل السلوكي (إذا فشلت المؤشرات القياسية)
    if (posts.length < 3) {
        console.log('⚠️ المؤشرات القياسية غير كافية، جاري التحليل السلوكي...');
        const allDivs = root.querySelectorAll('div');
        posts = Array.from(allDivs).filter(div => {
            const text = cleanText(div.innerText || '');
            
            if (text.length < 25) return false;
            
            // الكلمات المفتاحية للإعلانات العربية
            const keywords = [
                'للبيع', 'مطلوب', 'شقة', 'سيارة', 'أرض', 'عقار',
                'للايجار', 'وظيفة', 'فرصة', 'مستعمل', 'جديد',
                'ريال', 'درهم', 'دينار', 'سعر', 'تخفيض'
            ];
            
            const hasKeywords = keywords.some(keyword => text.includes(keyword));
            const hasPhone = extractPhone(text) !== null;
            const hasContact = text.includes('واتساب') || text.includes('اتصل') || text.includes('اتصال');
            
            return (hasKeywords && text.length > 50) || hasPhone || hasContact;
        });
    }
    
    return posts;
}

// ===================================================================
// 🛠️ معالجة المنشورات
// ===================================================================

/**
 * معالجة منشور واحد
 */
function processPost(post) {
    if (post.hasAttribute('data-fb-fyras-scraped')) return;
    post.setAttribute('data-fb-fyras-scraped', 'true');
    
    // إنشاء زر الحفظ
    const btn = document.createElement('button');
    btn.className = 'fb-fyras-save-btn';
    btn.innerHTML = '💾 <span style="font-family: Arial, sans-serif">حفظ</span>';
    btn.style.cssText = `
        background: #1877f2;
        color: white;
        border: none;
        padding: 6px 12px;
        border-radius: 4px;
        margin: 8px 0;
        display: block;
        cursor: pointer;
        font-size: 14px;
        font-weight: bold;
        font-family: inherit;
        transition: all 0.3s;
        box-shadow: 0 1px 3px rgba(0,0,0,0.2);
    `;
    
    // سلوك الزر عند النقر
    btn.onclick = function(event) {
        event.preventDefault();
        event.stopPropagation();
        
        if (btn.getAttribute('data-saving') === 'true') return;
        btn.setAttribute('data-saving', 'true');
        
        try {
            // جمع البيانات
            const postText = cleanText(post.innerText || '');
            
            // استخراج اسم الناشر
            let authorName = 'ناشر مجهول';
            let authorProfileUrl = '';
            
            const authorSelectors = [
                'a[aria-label]',
                '.actor-link',
                'h5',
                'a[href*="/user/"]',
                'a[href*="/profile/"]',
                '[aria-label*="صفحة"]',
                '[aria-label*="حساب"]'
            ];
            
            for (const selector of authorSelectors) {
                const authorElement = post.querySelector(selector);
                if (authorElement) {
                    const name = cleanText(authorElement.innerText || authorElement.getAttribute('aria-label') || '');
                    if (name.length > 2 && name.length < 50 && !name.includes('·')) {
                        authorName = name;
                        if (authorElement.href) authorProfileUrl = authorElement.href;
                        break;
                    }
                }
            }
            
            // عد الوسائط
            const mediaCount = post.querySelectorAll('img:not([aria-hidden="true"]), video').length;
            
            // تحديد وسيلة التواصل (محسّن)
            let contactInfo = '';
            const phoneNumber = extractPhone(postText);
            
            if (phoneNumber) {
                contactInfo = 'واتساب: ' + phoneNumber;
            } else if (authorProfileUrl) {
                const messengerUrl = authorProfileUrl
                    .replace('www.facebook.com', 'm.me')
                    .replace('facebook.com', 'm.me')
                    .split('?')[0];
                contactInfo = 'ماسنجر: ' + messengerUrl;
            } else {
                contactInfo = 'التواصل: خاص (عبر فيسبوك)';
            }
            
            // الرابط الأصلي
            let originalPostUrl = window.location.href;
            const linkSelectors = [
                'a[href*="/posts/"]',
                'a[href*="/story/"]',
                'a[href*="/permalink/"]',
                'a[aria-label*="منشور"]',
                'a[href*="/photo/"]'
            ];
            
            for (const selector of linkSelectors) {
                const link = post.querySelector(selector);
                if (link && link.href && !link.href.includes('comment')) {
                    originalPostUrl = link.href;
                    break;
                }
            }
            
            // تجهيز البيانات للإرسال
            const postData = {
                original_text: postText,
                original_author: authorName,
                author_profile_url: authorProfileUrl || '',
                contact_info: contactInfo,
                original_post_url: originalPostUrl,
                shared_from_url: window.location.href !== originalPostUrl ? window.location.href : null,
                scraped_at: new Date().toISOString(),
                media_count: mediaCount,
                platform: 'facebook'
            };
            
            // إرسال البيانات
            if (window.FlutterApp) {
                window.FlutterApp.postMessage(JSON.stringify(postData));
                
                // تحديث الزر
                btn.innerHTML = '✓ <span style="font-family: Arial, sans-serif">تم الحفظ</span>';
                btn.style.background = '#4CAF50';
                post.style.backgroundColor = 'rgba(24, 119, 242, 0.1)';
                
                // تغيير السلوب إلى إزالة
                const originalUrl = originalPostUrl;
                btn.onclick = function() {
                    if (window.FlutterApp) {
                        window.FlutterApp.postMessage('REMOVE:' + originalUrl);
                    }
                    btn.innerHTML = '💾 <span style="font-family: Arial, sans-serif">حفظ</span>';
                    btn.style.background = '#1877f2';
                    post.style.backgroundColor = '';
                    post.removeAttribute('data-fb-fyras-scraped');
                    btn.onclick = arguments.callee;
                };
            }
            
        } catch (error) {
            console.error('❌ خطأ في معالجة المنشور:', error);
            btn.innerHTML = '⚠️ <span style="font-family: Arial, sans-serif">خطأ</span>';
            btn.style.background = '#f44336';
            
            setTimeout(() => {
                btn.innerHTML = '💾 <span style="font-family: Arial, sans-serif">حفظ</span>';
                btn.style.background = '#1877f2';
                btn.removeAttribute('data-saving');
            }, 3000);
        }
        
        btn.removeAttribute('data-saving');
    };
    
    // إضافة الزر إلى المنشور
    try {
        const contentContainer = post.querySelector('[data-ad-preview="message"], .userContent, div:not([class]):not([id])');
        if (contentContainer) {
            contentContainer.parentNode.insertBefore(btn, contentContainer.nextSibling);
        } else {
            post.insertBefore(btn, post.firstChild);
        }
    } catch (error) {
        post.appendChild(btn);
    }
}

// ===================================================================
// 👁️ نظام المراقبة المحسّن
// ===================================================================

/**
 * مراقبة التغييرات باستخدام MutationObserver
 */
function initializeObserver() {
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            if (mutation.addedNodes.length > 0) {
                mutation.addedNodes.forEach((node) => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        const posts = findPosts(node);
                        posts.forEach((post, index) => {
                            setTimeout(() => processPost(post), index * 30);
                        });
                    }
                });
            }
        });
        
        detectLoginSuccess();
    });
    
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    return observer;
}

// ===================================================================
// 🔄 نظام التحقق الدوري المحسّن (باستخدام requestAnimationFrame)
// ===================================================================

/**
 * التحقق من المنشورات الفائتة (أداء أفضل)
 */
function checkMissedPosts() {
    if (document.visibilityState !== 'visible') return;
    
    try {
        const missedPosts = document.querySelectorAll(`
            [role="article"]:not([data-fb-fyras-scraped]),
            div[data-testid="post"]:not([data-fb-fyras-scraped]),
            .userContentWrapper:not([data-fb-fyras-scraped])
        `);
        
        if (missedPosts.length > 0) {
            missedPosts.forEach((post, index) => {
                setTimeout(() => processPost(post), index * 50);
            });
        }
    } catch (error) {
        console.error('❌ خطأ في التحقق من المنشورات الفائتة:', error);
    }
    
    if (document.visibilityState === 'visible') {
        requestAnimationFrame(checkMissedPosts);
    }
}

// ===================================================================
// 🚀 تهيئة النظام الرئيسي
// ===================================================================

/**
 * الدالة الرئيسية للتهيئة
 */
function initializeScraper() {
    console.log('🚀 تهيئة نظام Fb Explorer Fyras...');
    
    // معالجة المنشورات الموجودة
    const initialPosts = findPosts(document.body);
    initialPosts.forEach((post, index) => {
        setTimeout(() => processPost(post), index * 100);
    });
    
    // تهيئة المراقب
    initializeObserver();
    
    // بدء النظام الدوري
    if (document.visibilityState === 'visible') {
        requestAnimationFrame(checkMissedPosts);
    }
    
    // مراقبة تغيير حالة الصفحة
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') {
            requestAnimationFrame(checkMissedPosts);
        }
    });
    
    console.log(`✅ تم تهيئة النظام وتمت معالجة ${initialPosts.length} منشور`);
}

// ===================================================================
// 📅 بدء التنفيذ
// ===================================================================

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeScraper);
} else {
    initializeScraper();
}

// إعادة التهيئة عند تغيير الصفحة
let lastUrl = location.href;
new MutationObserver(() => {
    if (location.href !== lastUrl) {
        lastUrl = location.href;
        setTimeout(initializeScraper, 1000);
    }
}).observe(document, { subtree: true, childList: true });

// ===================================================================
// 📝 ملاحظات النهاية
// ===================================================================
/*
✅ المميزات المحسّنة في هذا الإصدار:
1. دعم كامل للأرقام العربية والإنجليزية والمختلطة
2. اكتشاف محسّن للمنشورات باستخدام مؤشرات متعددة
3. أداء أفضل مع requestAnimationFrame بدلاً من setInterval
4. معالجة أخطاء شاملة
5. واجهة مستخدم أفضل للأزرار
*/
