#!/usr/bin/env bash

# Terminal colors for clean output
BOLD='\033[1m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BOLD}Usage:${NC} $0 -p <home_price> -d <down_payment> -r <annual_interest_rate> [-y <loan_years>]"
    echo ""
    echo "Options:"
    echo "  -p  Home purchase price (e.g., 400000 or \$400,000)"
    echo "  -d  Down payment amount in dollars OR percentage (e.g., 80000 or 20%)"
    echo "  -r  Annual interest rate percentage (e.g., 6.5 or 6.5%)"
    echo "  -y  Loan term in years (optional, default: 30)"
    echo "  -h  Display this help message"
    exit 1
}

# Default values
YEARS=30

# Parse command line options
while getopts "p:d:r:y:h" opt; do
    case ${opt} in
        p) PRICE=${OPTARG} ;;
        d) DOWN=${OPTARG} ;;
        r) RATE=${OPTARG} ;;
        y) YEARS=${OPTARG} ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Ensure required parameters are provided
if [ -z "$PRICE" ] || [ -z "$DOWN" ] || [ -z "$RATE" ]; then
    echo "Error: Missing required arguments."
    usage
fi

# Ensure bc is installed for floating-point calculations
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' (basic calculator) is required but not installed."
    exit 1
fi

# Sanitize inputs: remove '$', ',', '%', and spaces
PRICE=$(echo "$PRICE" | tr -d '$, ')
RATE=$(echo "$RATE" | tr -d '$, %')
YEARS=$(echo "$YEARS" | tr -d '$, ')

# Determine if down payment is given as a percentage or fixed dollar amount
if [[ "$DOWN" == *%* ]]; then
    CLEAN_DOWN=$(echo "$DOWN" | tr -d '$, %')
    DOWN_PAYMENT=$(echo "scale=2; $PRICE * ($CLEAN_DOWN / 100)" | bc -l)
else
    DOWN_PAYMENT=$(echo "$DOWN" | tr -d '$, ')
fi

# Calculate Principal (Loan Amount)
PRINCIPAL=$(echo "scale=2; $PRICE - $DOWN_PAYMENT" | bc -l)

# Validate principal amount
IS_INVALID=$(echo "$PRINCIPAL <= 0" | bc -l)
if [ "$IS_INVALID" -eq 1 ]; then
    echo "Error: Down payment must be strictly less than the home purchase price."
    exit 1
fi

# Monthly Interest Rate (r) = Annual Rate / 100 / 12
R=$(echo "scale=10; $RATE / 100 / 12" | bc -l)

# Total Number of Monthly Payments (n) = Years * 12
N=$(echo "$YEARS * 12" | bc)

# Calculate Monthly Payment (Handles 0% interest rate safely)
IS_ZERO_RATE=$(echo "$R == 0" | bc -l)
if [ "$IS_ZERO_RATE" -eq 1 ]; then
    PAYMENT=$(echo "scale=2; $PRINCIPAL / $N" | bc -l)
else
    PAYMENT=$(bc -l <<EOF
scale=10
pow = (1 + $R)^$N
m = $PRINCIPAL * ($R * pow) / (pow - 1)
scale=2
m / 1
EOF
)
fi

# Total Paid and Total Interest
TOTAL_PAID=$(echo "scale=2; $PAYMENT * $N" | bc -l)
TOTAL_INTEREST=$(echo "scale=2; $TOTAL_PAID - $PRINCIPAL" | bc -l)

# Ensure standard decimal formatting across different shell environments
LC_NUMERIC=C

# Output Summary
echo -e "\n${BOLD}=== Mortgage Payment Breakdown ===${NC}"
printf "Home Purchase Price:   \$%.2f\n" "$PRICE"
printf "Down Payment:          \$%.2f\n" "$DOWN_PAYMENT"
printf "Loan Principal:        \$%.2f\n" "$PRINCIPAL"
printf "Interest Rate:         %.2f%%\n" "$RATE"
printf "Loan Duration:         %d years (%d months)\n" "$YEARS" "$N"
echo "----------------------------------"
printf "${BOLD}Monthly Principal & Interest: \$%.2f${NC}\n" "$PAYMENT"
printf "Total Interest Paid:         \$%.2f\n" "$TOTAL_INTEREST"
printf "Total Amount Paid:           \$%.2f\n\n" "$TOTAL_PAID"