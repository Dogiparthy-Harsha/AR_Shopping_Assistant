import React from 'react';
import { ExternalLink, Star, Tag, Archive } from 'lucide-react';

const A2UIButton = ({ component }) => {
    return (
        <a
            href={component.action}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-4 py-2 mt-2 bg-purple-600 hover:bg-purple-700 text-white text-sm font-medium rounded-lg transition-colors"
        >
            {component.label}
            <ExternalLink size={16} />
        </a>
    );
};

const A2UIText = ({ component }) => {
    return (
        <p className="text-gray-200 text-sm my-1">{component.content}</p>
    );
};

const A2UIBox = ({ component }) => {
    return (
        <div className="flex flex-col gap-2 p-2 border border-gray-700/50 rounded-lg bg-black/40 backdrop-blur-md">
            {component.children.map((child, idx) => (
                <A2UIRenderer key={idx} component={child} />
            ))}
        </div>
    );
};

const A2UIImage = ({ component }) => {
    return (
        <img
            src={component.src}
            alt={component.alt || 'Product image'}
            className="w-full h-32 object-contain rounded-md bg-white/10"
        />
    );
};

const A2UICard = ({ component }) => {
    return (
        <div className="flex flex-col p-4 mb-4 rounded-xl border border-white/10 bg-black/60 backdrop-blur-xl shadow-xl hover:shadow-purple-500/20 transition-all duration-300 transform hover:-translate-y-1">
            {component.title && <h3 className="text-lg font-bold text-white mb-2 line-clamp-2">{component.title}</h3>}
            {component.image && <A2UIImage component={component.image} />}

            <div className="mt-3 flex flex-col gap-1">
                {component.meta && Object.entries(component.meta).map(([key, value]) => {
                    if (key === 'Price') {
                        return (
                            <div key={key} className="flex items-center gap-2 text-green-400 font-semibold text-lg">
                                <Tag size={16} /> <span>{value}</span>
                            </div>
                        );
                    }
                    if (key === 'Rating') {
                        return (
                            <div key={key} className="flex items-center gap-2 text-yellow-500 text-sm">
                                <Star size={14} fill="currentColor" /> <span>{value}</span>
                            </div>
                        );
                    }
                    if (key === 'Condition') {
                        return (
                            <div key={key} className="flex items-center gap-2 text-blue-300 text-sm">
                                <Archive size={14} /> <span>{value}</span>
                            </div>
                        );
                    }
                    return (
                        <div key={key} className="text-xs text-gray-400">
                            <span className="font-semibold text-gray-300">{key}:</span> {value}
                        </div>
                    );
                })}
            </div>

            <div className="mt-2 flex flex-col gap-2">
                {component.children?.map((child, idx) => (
                    <A2UIRenderer key={idx} component={child} />
                ))}
            </div>
        </div>
    );
};

const A2UIList = ({ component }) => {
    return (
        <div className="flex flex-col gap-3">
            {component.items.map((item, idx) => (
                <A2UIRenderer key={idx} component={item} />
            ))}
        </div>
    );
};

export const A2UIRenderer = ({ component }) => {
    if (!component) return null;

    switch (component.type) {
        case 'card':
            return <A2UICard component={component} />;
        case 'list':
            return <A2UIList component={component} />;
        case 'button':
            return <A2UIButton component={component} />;
        case 'text':
            return <A2UIText component={component} />;
        case 'box':
            return <A2UIBox component={component} />;
        case 'image':
            return <A2UIImage component={component} />;
        default:
            console.warn('Unknown A2UI component type:', component.type);
            return null;
    }
};

/**
 * A side panel layout showing Amazon vs eBay results
 */
export default function ResultsLayout({ a2uiJson }) {
    if (!a2uiJson || !a2uiJson.type) return null;

    // We need to parse out amazon and ebay parts
    // `a2uiJson` usually comes as a List or a Box from the backend containing multiple items.
    // We'll iterate through all cards and check their metadata/titles to classify them,
    // OR we can just check if they contain 'Rainforest' or 'eBay'.

    const allCards = [];

    const extractCards = (comp) => {
        if (!comp) return;
        if (comp.type === 'card') {
            allCards.push(comp);
        }
        if (comp.children) {
            comp.children.forEach(extractCards);
        }
        if (comp.items) {
            comp.items.forEach(extractCards);
        }
    };

    extractCards(a2uiJson);

    // Separate the cards
    const amazonCards = [];
    const ebayCards = [];

    allCards.forEach(card => {
        const isEbay = card.meta && card.meta.Condition !== undefined; // eBay has Condition, Amazon usually doesn't in this API
        const isAmazon = card.meta && card.meta.Rating !== undefined;

        // Fallback: check buttons or title
        let hasAmazonLink = false;
        let hasEbayLink = false;
        card.children?.forEach(c => {
            if (c.type === 'button') {
                if (c.action?.includes('amazon.com')) hasAmazonLink = true;
                if (c.action?.includes('ebay.com')) hasEbayLink = true;
            }
        });

        if (isAmazon || hasAmazonLink) {
            amazonCards.push(card);
        } else if (isEbay || hasEbayLink) {
            ebayCards.push(card);
        } else {
            // Unclassified? default to alternating
            if (amazonCards.length <= ebayCards.length) amazonCards.push(card);
            else ebayCards.push(card);
        }
    });

    return (
        <>
            {/* Left panel (eBay) */}
            <div className="absolute top-0 left-0 w-[400px] h-full p-6 pt-24 overflow-y-auto no-scrollbar pointer-events-auto">
                {ebayCards.length > 0 && (
                    <div className="animate-fade-in-right">
                        <div className="flex items-center gap-2 mb-4 drop-shadow-lg">
                            <div className="w-8 h-8 rounded bg-blue-600 flex items-center justify-center text-white font-bold text-sm">e</div>
                            <h2 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-blue-600 bg-clip-text text-transparent">eBay Matches</h2>
                        </div>
                        {ebayCards.map((c, i) => <A2UICard key={i} component={c} />)}
                    </div>
                )}
            </div>

            {/* Right panel (Amazon) */}
            <div className="absolute top-0 right-0 w-[400px] h-full p-6 pt-24 overflow-y-auto no-scrollbar pointer-events-auto">
                {amazonCards.length > 0 && (
                    <div className="animate-fade-in-left">
                        <div className="flex items-center gap-2 mb-4 drop-shadow-lg justify-end">
                            <h2 className="text-2xl font-bold bg-gradient-to-r from-yellow-400 to-orange-500 bg-clip-text text-transparent">Amazon Matches</h2>
                            <div className="w-8 h-8 rounded bg-orange-500 flex items-center justify-center text-white font-bold text-sm">A</div>
                        </div>
                        {amazonCards.map((c, i) => <A2UICard key={i} component={c} />)}
                    </div>
                )}
            </div>
        </>
    );
}
