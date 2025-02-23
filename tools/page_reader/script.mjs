#!/usr/bin/env node

import { JSDOM } from 'jsdom';
import { Readability } from '@mozilla/readability';
import axios from 'axios';

async function extractContent(url) {
	try {
		// Fetch the HTML content of the webpage
		const response = await axios.get(url, {
			headers: {
				Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
				'Accept-Language': 'en-US,en;q=0.7,el;q=0.3',
				'Cache-Control': 'no-cache',
				'Connection': 'keep-alive',
				DNT: '1',
				Pragma: 'no-cache',
				Priority: 'u=0, i',
				'Upgrade-Insecure-Requests': '1',
				'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0',
			},
		});

		let html = response.data;
		if (typeof html !== 'object') {
			// Create a DOM object from the HTML
			const dom = new JSDOM(html, { url });

			// Create a new Readability object and parse the content
			const reader = new Readability(dom.window.document);
			const article = reader.parse();
			html = article.textContent;
		}

		return {
			'status': true,
			'content': html,
		};
	} catch (error) {
		return {
			'status': false,
			'content': error.message,
		};
	}
}

// Usage
const targetUrl = process.argv[2];
const result = await extractContent(targetUrl);

if (result.status) {
	process.stdout.write(result.content);
	process.exit(0);
}
else {
	process.stderr.write(result.content);
	process.exit(1);
}

