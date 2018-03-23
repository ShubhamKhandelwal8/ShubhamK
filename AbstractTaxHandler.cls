/*
 * FinancialForce.com, inc. claims copyright in this software, its screen display designs and 
 * supporting documentation. FinancialForce and FinancialForce.com are trademarks of FinancialForce.com, inc. 
 * Any unauthorized use, copying or sale of the above may constitute an infringement of copyright and may 
 * result in criminal or other legal proceedings. 
 *
 * Copyright (c) 2015 FinancialForce.com, inc. All rights reserved.
 */

public abstract class AbstractTaxHandler implements TaxHandler
{
	public class TaxSummaryImpl implements TaxEngine.ITaxSummary
	{
		private String m_taxCode;
		private Decimal m_taxRate;
		private Decimal m_netValue;
		private Decimal m_taxValue;

		public TaxSummaryImpl(String taxCode, Decimal taxRate, Decimal netValue, Decimal taxValue)
		{
			m_taxCode = taxCode;
			m_taxRate = taxRate;
			m_netValue = netValue;
			m_taxValue = taxValue;
		}

		public String getTaxCode()
		{
			return m_taxCode;
		}
		public Decimal getNetValue()
		{
			return m_netValue;
		}
		public void addToNetValue(Decimal netValue)
		{
			m_netValue += netValue;
		}
		public Decimal getTaxValue()
		{
			return m_taxValue;
		}
		public void addToTaxValue(Decimal taxValue)
		{
			m_taxValue += taxValue;
		}
		public Decimal getTaxRate()
		{
			return m_taxRate;
		}
	}

	// our query impl for when we need to go to the db.
	private TaxEngine.ITaxHandlerQuery m_query;

	public AbstractTaxHandler(TaxEngine.ITaxHandlerQuery qry)
	{
		m_query = qry;
	}

	/**
	*	Add to, or create the tax summary for the given tax code.
	*	@param taxSummaryItems map of existing summary items.
	*	@param taxCodeString the name of the tax code. Null is allowed as well, in which case a summary of the null taxcode will be created.
	*/
	protected void addToTaxSummary(Map<String, AbstractTaxHandler.TaxSummaryImpl> taxSummaryItems, String taxCodeString, Decimal taxRate, Decimal netValue, Decimal taxValue)
	{
		// this is a defensive measure. All tax values are normally 0.00, but there are certain cases that they get through as null
		// especially where older API versions have been involved.
		if(taxValue == null)
			taxValue = 0;

		AbstractTaxHandler.TaxSummaryImpl taxSummary = taxSummaryItems.get(taxCodeString);
		if (taxSummary == null)
		{
			taxSummary = new AbstractTaxHandler.TaxSummaryImpl(taxCodeString, taxRate, netValue, taxValue);
			taxSummaryItems.put(taxCodeString, taxSummary);
		}
		else
		{
			taxSummary.addToNetValue(netValue);
			taxSummary.addToTaxValue(taxValue);
		}
	}


	/**
	*	Simple calculation. net * rate.
	*/
	public Decimal calculateTaxValue(Decimal net, Decimal rate, DocumentModel.ICurrency curr)
	{
		if(rate == null || net == null || curr == null)
			return null;

		return CODAMath.round( net * CODAMath.divide(rate, 100), curr.getDecimalPlaces());
	}
	
	/**
	*	This seems common code - look up the tax rate on the db for a given date.
	*/
	public virtual Decimal getTaxRateAsDecimal(DocumentModel.IDocument document, DocumentModel.ITaxCode taxCode)
	{
		if (taxCode != null)
		{
			// TODO: don't use CodaTaxRate, be patterns agnostic.
			try
			{
				Decimal rate = m_query.getTaxRateByStartDate(document.getTaxRateDate(), taxCode);

				if(rate != null)
				{
					return rate;
				}
				else
				{
					if(!document.isComplete() && !document.isDiscarded())
					{
						document.missingTaxRateError(document.getTaxRateDate(), taxCode);
					}
				}
			}
			catch(Exception e)
			{
				document.missingTaxRateError(document.getTaxRateDate(), taxCode);
				return  0;
			}
			
		}

		return 0;
	}

	protected List<TaxEngine.ITaxSummary> sortTaxSummaryItems(List<TaxEngine.ITaxSummary> taxSummaries)
	{
		CODASort codaSort = new CODASort();

		for(Integer i = 0; i < taxSummaries.size(); i++)
		{
			codaSort.add(taxSummaries[i].getTaxCode(), i);
		}

		List<TaxEngine.ITaxSummary> sortedTaxSummaries = new List<TaxEngine.ITaxSummary>();

		for (Integer i : codaSort.values())
		{
			sortedTaxSummaries.add(taxSummaries[i]);
		}

		return sortedTaxSummaries;
	}

	public void validateHasNoTaxFields(DocumentModel.IIntegrationRule line)
	{
		if(line.hasTaxCode1() || line.hasTaxRate1()  || line.hasTaxValue1() ||
			line.hasTaxCode2() || line.hasTaxRate2()  || line.hasTaxValue2() ||
			line.hasTaxCode3() || line.hasTaxRate3() || line.hasTaxValue3())
		{
			throw new CODAException(Label.codaIntegrationRuleCannotMapTax);
		}
	}

	protected void setNullTaxValuesToZero(DocumentModel.ILine line)
	{
		// this line is here in case we are still null. We have an unfortunate rule
		// that we convert nulls to zeros (on new lines at any rate).
		// we have to do this to all tax values, even though we only deal with tax 1 normally.
		if(line.getTaxValue1() == null)
		{
			line.setTaxValue1(0.00);
		}
		if(line.getTaxValue2() == null)
		{
			line.setTaxValue2(0.00);
		}
		if(line.getTaxValue3() == null)
		{
			line.setTaxValue3(0.00);
		}
	}
}