-- =====================================================
-- FRAUD ALERT THRESHOLD OPTIMIZATION - SQL QUERIES
-- =====================================================

-- Query 1: Fraud Rate by Category
-- Business Use: Identify high-risk merchant categories
SELECT 
    category,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    ROUND(AVG(amt), 2) as avg_transaction_amount
FROM transactions
GROUP BY category
ORDER BY fraud_rate_pct DESC
LIMIT 10;

-- =====================================================

-- Query 2: Cost Analysis by Threshold Simulation
-- Business Use: Calculate total cost at different alert thresholds
WITH threshold_results AS (
    SELECT 
        trans_id,
        is_fraud as actual_fraud,
        fraud_probability,
        CASE 
            WHEN fraud_probability >= 0.50 THEN 1 
            ELSE 0 
        END as predicted_fraud_50,
        CASE 
            WHEN fraud_probability >= 0.70 THEN 1 
            ELSE 0 
        END as predicted_fraud_70
    FROM fraud_predictions
)
SELECT 
    'Threshold 0.50' as threshold_version,
    SUM(CASE 
        WHEN actual_fraud = 0 AND predicted_fraud_50 = 1 THEN 15  -- False Positive
        WHEN actual_fraud = 1 AND predicted_fraud_50 = 0 THEN 750 -- False Negative
        WHEN actual_fraud = 1 AND predicted_fraud_50 = 1 THEN 5   -- True Positive
        ELSE 0 
    END) as total_cost
FROM threshold_results

UNION ALL

SELECT 
    'Threshold 0.70' as threshold_version,
    SUM(CASE 
        WHEN actual_fraud = 0 AND predicted_fraud_70 = 1 THEN 15  -- False Positive
        WHEN actual_fraud = 1 AND predicted_fraud_70 = 0 THEN 750 -- False Negative
        WHEN actual_fraud = 1 AND predicted_fraud_70 = 1 THEN 5   -- True Positive
        ELSE 0 
    END) as total_cost
FROM threshold_results;

-- =====================================================

-- Query 3: Customer Segment Analysis
-- Business Use: Check if optimal threshold varies by customer segment
SELECT 
    CASE 
        WHEN city_pop < 50000 THEN 'Small City'
        WHEN city_pop < 200000 THEN 'Medium City'
        ELSE 'Large City'
    END as city_segment,
    COUNT(*) as transaction_count,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraud_count,
    ROUND(AVG(amt), 2) as avg_amount,
    ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct
FROM transactions
GROUP BY city_segment
ORDER BY fraud_rate_pct DESC;

-- =====================================================

-- Query 4: Time-Based Fraud Trends
-- Business Use: Identify temporal patterns in fraud
SELECT 
    DATE_TRUNC('month', trans_date) as month,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    ROUND(AVG(amt), 2) as avg_transaction_amount
FROM transactions
GROUP BY month
ORDER BY month;

-- =====================================================

-- Query 5: Confusion Matrix Metrics by Threshold
-- Business Use: Calculate precision, recall, F1 for different thresholds
WITH predictions AS (
    SELECT 
        is_fraud as actual,
        CASE WHEN fraud_probability >= 0.70 THEN 1 ELSE 0 END as predicted
    FROM fraud_predictions
),
metrics AS (
    SELECT 
        SUM(CASE WHEN actual = 1 AND predicted = 1 THEN 1 ELSE 0 END) as true_positives,
        SUM(CASE WHEN actual = 0 AND predicted = 1 THEN 1 ELSE 0 END) as false_positives,
        SUM(CASE WHEN actual = 1 AND predicted = 0 THEN 1 ELSE 0 END) as false_negatives,
        SUM(CASE WHEN actual = 0 AND predicted = 0 THEN 1 ELSE 0 END) as true_negatives
    FROM predictions
)
SELECT 
    true_positives,
    false_positives,
    false_negatives,
    true_negatives,
    ROUND(100.0 * true_positives / NULLIF(true_positives + false_positives, 0), 2) as precision_pct,
    ROUND(100.0 * true_positives / NULLIF(true_positives + false_negatives, 0), 2) as recall_pct,
    ROUND(2.0 * (true_positives / NULLIF(true_positives + false_positives, 0)) * 
          (true_positives / NULLIF(true_positives + false_negatives, 0)) / 
          NULLIF((true_positives / NULLIF(true_positives + false_positives, 0)) + 
          (true_positives / NULLIF(true_positives + false_negatives, 0)), 0), 2) as f1_score
FROM metrics;

-- =====================================================

-- Query 6: High-Value Transaction Risk Analysis
-- Business Use: Focus fraud prevention on high-value transactions
SELECT 
    CASE 
        WHEN amt < 50 THEN 'Low ($0-50)'
        WHEN amt < 200 THEN 'Medium ($50-200)'
        WHEN amt < 500 THEN 'High ($200-500)'
        ELSE 'Very High ($500+)'
    END as amount_bucket,
    COUNT(*) as transaction_count,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amt ELSE 0 END), 2) as total_fraud_amount
FROM transactions
GROUP BY amount_bucket
ORDER BY 
    CASE 
        WHEN amt < 50 THEN 1
        WHEN amt < 200 THEN 2
        WHEN amt < 500 THEN 3
        ELSE 4
    END;