// ========================================
// SAHLA DELIVERY - LOCALIZATION SYSTEM
// ========================================

class Localization {
    constructor() {
        this.currentLang = localStorage.getItem('sahla-lang') || 'en';
        this.translations = translations;
        this.init();
    }

    init() {
        // Set initial language
        this.setLanguage(this.currentLang);

        // Setup language switcher
        this.setupLanguageSwitcher();
    }

    setLanguage(lang) {
        if (!this.translations[lang]) {
            lang = 'en'; // Fallback to English
        }

        this.currentLang = lang;
        localStorage.setItem('sahla-lang', lang);

        // Update HTML lang attribute
        document.documentElement.lang = lang;

        // Update dir attribute for RTL
        if (lang === 'ar') {
            document.documentElement.dir = 'rtl';
            document.body.classList.add('rtl');
        } else {
            document.documentElement.dir = 'ltr';
            document.body.classList.remove('rtl');
        }

        // Update all translatable elements
        this.updateTranslations();

        // Update language button
        const langCode = document.getElementById('langCode');
        if (langCode) {
            langCode.textContent = languageNames[lang];
        }

        // Dispatch language change event for cookie consent
        document.dispatchEvent(new CustomEvent('languageChanged', { detail: { lang } }));

        // Close dropdown
        const dropdown = document.getElementById('langDropdown');
        const langBtn = document.getElementById('langBtn');
        if (dropdown) {
            dropdown.classList.remove('active');
        }
        if (langBtn) {
            langBtn.setAttribute('aria-expanded', 'false');
            const chevron = langBtn.querySelector('.lang-chevron');
            if (chevron) {
                chevron.style.transform = 'rotate(0deg)';
            }
        }
    }

    updateTranslations() {
        const t = this.translations[this.currentLang];

        // Update all elements with data-i18n attribute
        document.querySelectorAll('[data-i18n]').forEach(element => {
            const key = element.getAttribute('data-i18n');
            if (t[key]) {
                element.textContent = t[key];
            }
        });

        // Update elements with data-i18n-html (for HTML content)
        document.querySelectorAll('[data-i18n-html]').forEach(element => {
            const key = element.getAttribute('data-i18n-html');
            if (t[key]) {
                element.innerHTML = t[key];
            }
        });

        // Update placeholder attributes
        document.querySelectorAll('[data-i18n-placeholder]').forEach(element => {
            const key = element.getAttribute('data-i18n-placeholder');
            if (t[key]) {
                element.placeholder = t[key];
            }
        });

        // Update title attributes
        document.querySelectorAll('[data-i18n-title]').forEach(element => {
            const key = element.getAttribute('data-i18n-title');
            if (t[key]) {
                element.title = t[key];
            }
        });
    }

    setupLanguageSwitcher() {
        const langBtn = document.getElementById('langBtn');
        const langDropdown = document.getElementById('langDropdown');
        const langOptions = document.querySelectorAll('.lang-option');

        if (!langBtn || !langDropdown) return;

        // Toggle dropdown
        langBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            const isActive = langDropdown.classList.toggle('active');
            langBtn.setAttribute('aria-expanded', isActive.toString());
            // Update chevron rotation
            const chevron = langBtn.querySelector('.lang-chevron');
            if (chevron) {
                if (isActive) {
                    chevron.style.transform = 'rotate(180deg)';
                } else {
                    chevron.style.transform = 'rotate(0deg)';
                }
            }
        });

        // Helper function to close dropdown and reset chevron
        const closeDropdown = () => {
            langDropdown.classList.remove('active');
            langBtn.setAttribute('aria-expanded', 'false');
            const chevron = langBtn.querySelector('.lang-chevron');
            if (chevron) {
                chevron.style.transform = 'rotate(0deg)';
            }
        };

        // Close dropdown when clicking outside
        document.addEventListener('click', (e) => {
            if (!langBtn.contains(e.target) && !langDropdown.contains(e.target)) {
                closeDropdown();
            }
        });

        // Close dropdown on Escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && langDropdown.classList.contains('active')) {
                closeDropdown();
                langBtn.focus();
            }
        });

        // Handle language selection
        langOptions.forEach(option => {
            option.addEventListener('click', (e) => {
                e.stopPropagation();
                const lang = option.getAttribute('data-lang');
                if (lang && this.translations[lang]) {
                    this.setLanguage(lang);
                    closeDropdown();
                }
            });

            // Keyboard navigation
            option.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    option.click();
                }
            });
        });
    }

    getTranslation(key) {
        return this.translations[this.currentLang][key] || key;
    }
}

// Initialize localization when DOM is ready
let localization;
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        localization = new Localization();
    });
} else {
    localization = new Localization();
}

// Export for global access
window.localization = localization;
