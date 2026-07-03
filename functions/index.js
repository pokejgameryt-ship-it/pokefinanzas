const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.database();

exports.autoRedistribute = onSchedule({
  schedule: "every 24 hours",
  timeZone: "Europe/Madrid",
}, async (event) => {
  const today = new Date().getDate();
  console.log(`Running redistribution for day ${today}`);

  const usersSnapshot = await db.ref("users").once("value");
  const users = usersSnapshot.val();
  
  if (!users) {
    console.log("No users found");
    return;
  }

  for (const [uid, userData] of Object.entries(users)) {
    try {
      await processUserRedistribution(uid, userData, today);
    } catch (error) {
      console.error(`Error processing user ${uid}:`, error);
    }
  }
  
  console.log("Redistribution complete");
});

async function processUserRedistribution(uid, userData, today) {
  const settings = userData.redistributionSettings || {};
  const globalDay = settings.globalRedistributionDay || 1;
  const configs = userData.redistributionConfigs || {};
  const distributions = userData.distributions || {};

  // Find previous month's distribution
  const now = new Date();
  const prevDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const prevMonth = prevDate.getMonth() + 1;
  const prevYear = prevDate.getFullYear();
  
  const prevDist = findDistribution(distributions, prevMonth, prevYear);
  if (!prevDist) {
    console.log(`User ${uid}: No previous month distribution found`);
    return;
  }

  // Find or create current month's distribution
  const currentMonth = now.getMonth() + 1;
  const currentYear = now.getFullYear();
  let currentDist = findDistribution(distributions, currentMonth, currentYear);
  
  if (!currentDist) {
    // Create new distribution based on previous month
    currentDist = createNewDistribution(prevDist, currentMonth, currentYear);
  }

  let modified = false;

  // Process each non-automatic category
  for (const cat of (prevDist.categories || [])) {
    if (cat.isAutomatic) continue;

    const config = configs[cat.name] || {};
    const catDay = config.redistributionDay != null ? config.redistributionDay : globalDay;

    if (today !== catDay) continue;

    // Calculate base budget
    const base = cat.isFixed
      ? (cat.fixedAmount || 0)
      : ((prevDist.monthlyIncome || 0) * (cat.percentage || 0) / 100);

    const unspent = Math.max(0, base - (cat.spentAmount || 0));

    // Get redistribution percentages (default: 100% to self)
    const percentages = config.redistributionPercentages || { [cat.name]: 100 };

    // Apply redistributions to current distribution
    for (const [destName, pct] of Object.entries(percentages)) {
      const amount = unspent * pct / 100;
      applyRedistributionToCategory(currentDist, destName, amount);
    }

    modified = true;
  }

  if (modified) {
    // Recalculate savings (Ahorro)
    recalculateSavings(currentDist);
    
    // Save updated distribution
    const distId = currentDist.id || `${currentYear}-${currentMonth}`;
    currentDist.id = distId;
    await db.ref(`users/${uid}/distributions/${distId}`).set(currentDist);
    console.log(`User ${uid}: Updated distribution for ${currentMonth}/${currentYear}`);
  }
}

function findDistribution(distributions, month, year) {
  for (const [key, dist] of Object.entries(distributions)) {
    if (dist.month === month && dist.year === year) {
      return dist;
    }
  }
  return null;
}

function createNewDistribution(prevDist, newMonth, newYear) {
  const newCategories = (prevDist.categories || []).map(cat => ({
    name: cat.name,
    fixedAmount: cat.fixedAmount,
    percentage: cat.percentage,
    isFixed: cat.isFixed,
    spentAmount: 0,
    isAutomatic: cat.isAutomatic || false,
    redistributionPercentages: cat.redistributionPercentages || {},
  }));

  return {
    id: `${newYear}-${newMonth}`,
    month: newMonth,
    year: newYear,
    monthlyIncome: prevDist.monthlyIncome || 0,
    categories: newCategories,
  };
}

function applyRedistributionToCategory(dist, categoryName, amount) {
  if (!dist.categories) return;
  
  for (const cat of dist.categories) {
    if (cat.name === categoryName && !cat.isAutomatic) {
      if (!cat.redistributionReceived) cat.redistributionReceived = 0;
      cat.redistributionReceived += amount;
      break;
    }
  }
}

function recalculateSavings(dist) {
  if (!dist.categories) return;
  
  const savingsCat = dist.categories.find(c => c.isAutomatic);
  if (!savingsCat) return;

  let totalBudget = 0;
  for (const cat of dist.categories) {
    if (cat.isAutomatic) continue;
    const base = cat.isFixed
      ? (cat.fixedAmount || 0)
      : ((dist.monthlyIncome || 0) * (cat.percentage || 0) / 100);
    const redistributed = cat.redistributionReceived || 0;
    totalBudget += base + redistributed;
  }

  // Savings = income - total budgets
  savingsCat.fixedAmount = Math.max(0, (dist.monthlyIncome || 0) - totalBudget);
}
