// Cookie Consent Management
class CookieConsent {
    constructor() {
        this.cookieName = 'sahla-cookie-consent';
        this.cookieExpiry = 365; // days
        this.consentPopup = document.getElementById('cookieConsent');
        this.init();
    }

    init() {
        // Check if user has already made a choice
        if (!this.getConsent()) {
            this.showConsent();
        }

        // Setup event listeners
        this.setupEventListeners();

        // Update texts on initial load
        this.updateTexts();
    }

    setupEventListeners() {
        const acceptBtn = document.getElementById('cookieAccept');
        const rejectBtn = document.getElementById('cookieReject');
        const manageBtn = document.getElementById('cookieManage');
        const closeBtn = document.getElementById('cookieClose');
        const preferences = document.getElementById('cookiePreferences');
        const saveBtn = document.createElement('button');
        saveBtn.className = 'cookie-btn cookie-btn-primary';
        saveBtn.setAttribute('data-i18n', 'cookieSave');
        saveBtn.textContent = 'Save Preferences';
        saveBtn.id = 'cookieSave';
        saveBtn.style.display = 'none';

        if (acceptBtn) {
            acceptBtn.addEventListener('click', () => {
                this.acceptAll();
            });
        }

        if (rejectBtn) {
            rejectBtn.addEventListener('click', () => {
                this.rejectAll();
            });
        }

        if (manageBtn) {
            manageBtn.addEventListener('click', () => {
                if (preferences) {
                    const isVisible = preferences.style.display === 'block';
                    preferences.style.display = isVisible ? 'none' : 'block';
                    if (!isVisible) {
                        manageBtn.style.display = 'none';
                        const footer = this.consentPopup.querySelector('.cookie-consent-footer');
                        if (footer && !footer.querySelector('#cookieSave')) {
                            footer.insertBefore(saveBtn, footer.firstChild);
                            saveBtn.style.display = 'inline-block';
                        }
                        // Update save button text
                        this.updateTexts();
                    } else {
                        manageBtn.style.display = 'inline-block';
                        if (saveBtn.parentNode) {
                            saveBtn.parentNode.removeChild(saveBtn);
                        }
                    }
                }
            });
        }

        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.hideConsent();
                // Store minimal consent (essential only) if closed without selection
                if (!this.getConsent()) {
                    this.setConsent({ essential: true, analytics: false, marketing: false });
                }
            });
        }

        saveBtn.addEventListener('click', () => {
            this.savePreferences();
        });
    }

    showConsent() {
        if (this.consentPopup) {
            this.consentPopup.classList.add('active');
            document.body.style.overflow = 'hidden';
        }
    }

    hideConsent() {
        if (this.consentPopup) {
            this.consentPopup.classList.remove('active');
            document.body.style.overflow = '';
        }
    }

    acceptAll() {
        this.setConsent({
            essential: true,
            analytics: true,
            marketing: true
        });
        this.hideConsent();
        this.applyConsent();
    }

    rejectAll() {
        this.setConsent({
            essential: true,
            analytics: false,
            marketing: false
        });
        this.hideConsent();
        this.applyConsent();
    }

    savePreferences() {
        const essential = document.getElementById('cookieEssential')?.checked || true;
        const analytics = document.getElementById('cookieAnalytics')?.checked || false;
        const marketing = document.getElementById('cookieMarketing')?.checked || false;

        this.setConsent({
            essential: essential,
            analytics: analytics,
            marketing: marketing
        });

        // Hide preferences panel
        const preferences = document.getElementById('cookiePreferences');
        const manageBtn = document.getElementById('cookieManage');
        const saveBtn = document.getElementById('cookieSave');
        if (preferences) {
            preferences.style.display = 'none';
        }
        if (manageBtn) {
            manageBtn.style.display = 'inline-block';
        }
        if (saveBtn && saveBtn.parentNode) {
            saveBtn.parentNode.removeChild(saveBtn);
        }

        this.hideConsent();
        this.applyConsent();
    }

    setConsent(consent) {
        const consentData = {
            ...consent,
            timestamp: new Date().getTime()
        };
        const expiryDate = new Date();
        expiryDate.setTime(expiryDate.getTime() + (this.cookieExpiry * 24 * 60 * 60 * 1000));
        document.cookie = `${this.cookieName}=${JSON.stringify(consentData)}; expires=${expiryDate.toUTCString()}; path=/; SameSite=Lax`;
    }

    getConsent() {
        const cookies = document.cookie.split(';');
        for (let cookie of cookies) {
            const [name, value] = cookie.trim().split('=');
            if (name === this.cookieName) {
                try {
                    return JSON.parse(decodeURIComponent(value));
                } catch (e) {
                    return null;
                }
            }
        }
        return null;
    }

    applyConsent() {
        const consent = this.getConsent();
        if (consent) {
            // Apply analytics consent
            if (consent.analytics) {
                // Initialize analytics (e.g., Google Analytics)
                console.log('Analytics cookies enabled');
            } else {
                // Disable analytics
                console.log('Analytics cookies disabled');
            }

            // Apply marketing consent
            if (consent.marketing) {
                // Initialize marketing tools
                console.log('Marketing cookies enabled');
            } else {
                // Disable marketing
                console.log('Marketing cookies disabled');
            }
        }
    }

    updateTexts() {
        // Update cookie consent texts when language changes
        const localization = window.localization;
        if (localization) {
            const lang = localization.currentLang || 'en';
            const t = localization.translations[lang];
            if (t) {
                // Update all data-i18n elements in cookie consent
                const cookieConsent = document.getElementById('cookieConsent');
                if (cookieConsent) {
                    cookieConsent.querySelectorAll('[data-i18n^="cookie"]').forEach(element => {
                        const key = element.getAttribute('data-i18n');
                        if (t[key]) {
                            element.textContent = t[key];
                        }
                    });
                }
            }
        }
    }
}

// Initialize cookie consent when DOM is ready and localization is loaded
function initCookieConsent() {
    if (window.localization && window.translations) {
        window.cookieConsent = new CookieConsent();
    } else {
        // Wait a bit for localization to load
        setTimeout(initCookieConsent, 100);
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        initCookieConsent();
    });
} else {
    initCookieConsent();
}

// Listen for language changes
document.addEventListener('languageChanged', () => {
    if (window.cookieConsent) {
        window.cookieConsent.updateTexts();
    }
});
